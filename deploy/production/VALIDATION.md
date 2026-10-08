# Validação da release v1.1.0

Estado: preparação local; publicação da imagem ainda pendente.

- Source consolida as alterações atualmente aplicadas na VPS e a nova organização de participantes.
- Build incremental da aplicação passou na VPS; assets públicos e endpoint do grupo confirmados.
- Sintaxe/compilação Vue, lint e testes de estado de grupos passaram.
- Backend de administração de grupos validado em processo isolado; leitura real do grupo retornou 200.
- Nova instalação completa com esta stack ainda não homologada.
- Os testes reais de todas as mutações WhatsApp e a validação visual completa continuam pendentes.
- Esta release não recria nem altera a stack em execução na VPS.

A publicação pelo workflow crm-image.yml deve concluir antes de usar a tag da imagem.
