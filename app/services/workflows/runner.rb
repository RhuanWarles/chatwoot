# Walks a workflow graph for one run. `pending` is the frontier of nodes still to execute; an entry with a `resume_at`
# is a branch that is waiting. State is saved after every node, so a crashed job resumes where it stopped.
class Workflows::Runner
  class StepFailed < StandardError; end

  MAX_STEPS = 300

  def initialize(run)
    @run = run
    @workflow = run.automation_workflow
    @graph = @workflow.graph_model
    @context = Workflows::Context.new(run)
    @pending = run.pending.dup
    @trace = run.trace.dup
    @executed = Set.new(@trace.pluck('node_id'))
  end

  def perform
    Current.executed_by = @workflow
    @run.update!(status: 'running', resume_at: nil)
    steps = 0
    while (entry = take_due_entry)
      raise StepFailed, "step limit (#{MAX_STEPS}) reached" if (steps += 1) > MAX_STEPS

      execute(entry['node_id'])
    end
    finish
  rescue StandardError => e
    fail_run(e)
  ensure
    Current.executed_by = nil
  end

  private

  def take_due_entry
    now = Time.current
    index = @pending.index { |entry| entry['resume_at'].blank? || Time.zone.parse(entry['resume_at']) <= now }
    index && @pending.delete_at(index)
  end

  # A node reached by two branches still runs once per run, so joins cannot multiply messages and requests.
  def execute(node_id)
    return unless @executed.add?(node_id)

    node = @graph.node(node_id)
    return record(node_id, 'unknown', 'skipped', error: 'node no longer exists') unless node

    handle, resume_at = send(:"run_#{node[:type]}", node)
    @graph.targets(node[:id], handle).each { |target| @pending << { 'node_id' => target, 'resume_at' => resume_at&.iso8601 } }
    persist
  end

  def run_trigger(node)
    record(node[:id], 'trigger', 'ok', output: { 'event' => @run.trigger_event })
    'out'
  end

  def run_condition(node)
    data = node[:data]
    results = Array(data[:conditions]).map do |row|
      Workflows::Condition.met?(@context.value(row[:field]), row[:operator], @context.render(row[:value]))
    end
    matched = data[:match] == 'any' ? results.any? : results.all?
    record(node[:id], 'condition', 'ok', output: { 'result' => matched })
    matched ? 'true' : 'false'
  end

  def run_switch(node)
    data = node[:data]
    actual = @context.value(data[:field])
    matched = Array(data[:cases]).find { |item| Workflows::Condition.met?(actual, 'equals', @context.render(item[:value])) }
    record(node[:id], 'switch', 'ok', output: { 'value' => actual, 'branch' => matched ? matched[:id] : 'default' })
    matched ? matched[:id] : 'default'
  end

  def run_wait(node)
    data = node[:data]
    resume_at = Time.current + (Workflows::Graph::WAIT_UNITS.fetch(data[:unit]) * data[:amount].to_i)
    record(node[:id], 'wait', 'waiting', output: { 'resume_at' => resume_at.iso8601 })
    ['out', resume_at]
  end

  def run_action(node)
    data = node[:data]
    params = render_params(data)
    output = Workflows::ActionRunner.new(@context, @workflow).perform(data[:action], params)
    @context.reload!
    record(node[:id], 'action', 'ok', output: output.merge('action' => data[:action]))
    'out'
  rescue StandardError => e
    # A rejected update leaves its attributes on the shared record; the next node must read it fresh.
    @context.reload!
    record(node[:id], 'action', 'error', error: e.message.truncate(500), output: { 'action' => data[:action] })
    raise StepFailed, e.message unless data[:continue_on_error]

    'out'
  end

  # The url and body of a request are built from text that customers wrote, so what is inserted into them is encoded.
  def render_params(data)
    raw = data[:params] || {}
    return @context.render(raw) unless data[:action] == 'http_request'

    @context.render(raw.except('url', 'body')).merge(
      'url' => @context.render(raw['url'], escape: ->(text) { ERB::Util.url_encode(text) }),
      'body' => @context.render(raw['body'], escape: ->(text) { JSON.generate(text)[1..-2] })
    )
  end

  def record(node_id, type, status, output: nil, error: nil)
    @trace << { 'node_id' => node_id, 'type' => type, 'status' => status, 'output' => output, 'error' => error, 'at' => Time.current.iso8601 }.compact
  end

  def persist
    @run.update!(pending: @pending, trace: @trace, context: @context.state)
  end

  def finish
    return @run.update!(status: 'completed', pending: [], trace: @trace, context: @context.state, finished_at: Time.current) if @pending.empty?

    @run.update!(status: 'waiting', pending: @pending, trace: @trace, context: @context.state,
                 resume_at: @pending.pluck('resume_at').compact.map { |value| Time.zone.parse(value) }.min)
  end

  def fail_run(error)
    ChatwootExceptionTracker.new(error, account: @run.account).capture_exception unless error.is_a?(StepFailed)
    @run.update!(status: 'failed', error: error.message.truncate(500), pending: [], trace: @trace, context: @context.state,
                 finished_at: Time.current, resume_at: nil)
  end
end
