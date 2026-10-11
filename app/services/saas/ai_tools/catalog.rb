class Saas::AiTools::Catalog
  def self.for_agent(agent, playground: false)
    scope = agent.tools.where(account_id: agent.account_id, active: true)
    scope = scope.where(allow_in_playground: true) if playground
    scope.map(&:function_definition)
  end
end
