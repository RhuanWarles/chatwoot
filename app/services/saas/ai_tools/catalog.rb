class Saas::AiTools::Catalog
  INSTRUCTIONS = <<~TEXT.squish.freeze
    Você tem ferramentas para consultar informações e executar ações. Use-as sempre que a conversa exigir a informação ou a ação que elas
    fornecem, em vez de responder de memória ou supor dados. Antes de chamar uma ferramenta, confira se já tem todos os parâmetros
    obrigatórios; se faltar algum, pergunte ao cliente e só chame depois que ele responder. Nunca invente valores de parâmetros. Baseie a
    resposta no resultado retornado e não repita a mesma chamada com os mesmos argumentos. Se a ferramenta falhar, corrija os argumentos
    somente se o erro indicar o que está errado; caso contrário explique ao cliente, sem códigos nem detalhes técnicos, que não foi possível
    concluir agora e ofereça outra alternativa. Se o resultado indicar que o desfecho é incerto, não repita uma ação automaticamente, pois ela
    pode ter sido executada no destino. Nunca diga que uma ação foi concluída sem que o resultado da ferramenta confirme.
  TEXT

  def self.for_agent(agent, playground: false)
    scope = agent.tools.where(account_id: agent.account_id, active: true).order(:id)
    scope = scope.where(allow_in_playground: true) if playground
    scope.map(&:function_definition)
  end

  def self.instructions(definitions)
    INSTRUCTIONS if definitions.present?
  end
end
