# OAuth authorization codes and PKCE verifiers must not appear in request logs.
Rails.application.config.filter_parameters += [:code, :code_verifier]
