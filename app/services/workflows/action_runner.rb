class Workflows::ActionRunner
  class MissingRecord < StandardError; end

  HANDLERS = [
    Workflows::Actions::ConversationActions, Workflows::Actions::DealActions,
    Workflows::Actions::ContactActions, Workflows::Actions::IntegrationActions
  ].freeze
  NAMES = HANDLERS.flat_map { |handler| handler::NAMES }.freeze

  def initialize(context, workflow)
    @context = context
    @workflow = workflow
  end

  # Returns a small hash that is stored in the run trace.
  def perform(name, params)
    handler = HANDLERS.find { |item| item::NAMES.include?(name) }
    raise ArgumentError, "unknown action #{name}" unless handler

    handler.new(@context, @workflow).public_send(name, params) || {}
  end
end
