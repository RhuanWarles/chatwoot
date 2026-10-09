class CustomExceptions::AiAgentError < StandardError
  class Transient < CustomExceptions::AiAgentError; end
  class Busy < CustomExceptions::AiAgentError; end
end
