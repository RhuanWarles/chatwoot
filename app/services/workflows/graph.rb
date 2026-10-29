class Workflows::Graph
  NODE_TYPES = %w[trigger condition switch wait action].freeze
  WAIT_UNITS = { 'minutes' => 1.minute, 'hours' => 1.hour, 'days' => 1.day }.freeze
  MAX_NODES = 100

  attr_reader :nodes, :edges

  def initialize(raw)
    raw = (raw || {}).with_indifferent_access
    @nodes = Array(raw[:nodes]).map { |node| node.is_a?(Hash) ? node.with_indifferent_access : node }
    @edges = Array(raw[:edges]).map { |edge| edge.is_a?(Hash) ? edge.with_indifferent_access : edge }
  end

  def node(id)
    nodes.find { |item| item[:id] == id }
  end

  # `event` nil returns every trigger node (a manual test run starts from all of them).
  def triggers(event = nil)
    nodes.select { |item| item.is_a?(Hash) && item[:type] == 'trigger' && (event.nil? || event_of(item) == event) }
  end

  def event_of(trigger)
    trigger[:data][:event] if trigger[:data].is_a?(Hash)
  end

  def targets(node_id, handle)
    edges.select { |edge| edge[:source] == node_id && (edge[:sourceHandle].presence || 'out') == handle }.pluck(:target)
  end

  def errors
    return ['graph nodes and edges must be objects'] unless (nodes + edges).all?(Hash)

    structural_errors + node_errors + edge_errors + (cyclic? ? ['graph must not contain cycles'] : [])
  end

  private

  def structural_errors
    messages = []
    messages << "graph can have at most #{MAX_NODES} nodes" if nodes.size > MAX_NODES
    messages << 'node ids must be present and unique' if nodes.pluck(:id).then { |ids| ids.any?(&:blank?) || ids.uniq.size != ids.size }
    messages
  end

  def node_errors
    nodes.flat_map do |item|
      next ["unknown node type #{item[:type].inspect}"] unless NODE_TYPES.include?(item[:type])
      next ['node data must be an object'] unless item[:data].nil? || item[:data].is_a?(Hash)

      send(:"#{item[:type]}_errors", item[:data] || {})
    end
  end

  def trigger_errors(data)
    AutomationWorkflow::TRIGGER_EVENTS.include?(data[:event]) ? [] : ["unknown trigger event #{data[:event].inspect}"]
  end

  def condition_errors(data)
    errors = %w[all any].include?(data[:match]) ? [] : ['condition match must be all or any']
    errors + Array(data[:conditions]).flat_map { |condition| condition_row_errors(condition) }
  end

  def condition_row_errors(condition)
    return ['condition rows must be objects'] unless condition.is_a?(Hash)

    messages = []
    messages << 'condition field is required' if condition[:field].blank?
    messages << "unknown operator #{condition[:operator].inspect}" unless Workflows::Condition::OPERATORS.include?(condition[:operator])
    messages
  end

  def switch_errors(data)
    cases = Array(data[:cases])
    return ['switch cases must be objects'] unless cases.all?(Hash)

    messages = []
    messages << 'switch field is required' if data[:field].blank?
    messages << 'switch case ids must be present and unique' if cases.pluck(:id).then { |ids| ids.any?(&:blank?) || ids.uniq.size != ids.size }
    messages
  end

  def wait_errors(data)
    return [] if Integer(data[:amount], exception: false).to_i.positive? && WAIT_UNITS.key?(data[:unit])

    ['wait needs a positive amount and a unit (minutes, hours or days)']
  end

  def action_errors(data)
    Workflows::ActionRunner::NAMES.include?(data[:action]) ? [] : ["unknown action #{data[:action].inspect}"]
  end

  def edge_errors
    ids = nodes.pluck(:id)
    edges.filter_map do |edge|
      'edges must connect existing nodes' unless ids.include?(edge[:source]) && ids.include?(edge[:target]) && edge[:source] != edge[:target]
    end.uniq
  end

  def cyclic?
    graph = edges.group_by { |edge| edge[:source] }.transform_values { |list| list.pluck(:target) }
    visited = {}
    nodes.pluck(:id).any? { |id| cycle_from?(id, graph, visited) }
  end

  # Depth-first search: :visiting marks the current path, :done the nodes already proven acyclic.
  def cycle_from?(id, graph, visited)
    return visited[id] == :visiting if visited.key?(id)

    visited[id] = :visiting
    found = Array(graph[id]).any? { |target| cycle_from?(target, graph, visited) }
    visited[id] = :done
    found
  end
end
