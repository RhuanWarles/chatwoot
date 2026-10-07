# Confirmação de áudio e reconciliação de status — Evolution 2.3.7

Esta correção não gera stack e não foi aplicada remotamente. O patch
`patches/chatwoot-send-ack-v2.3.7.patch` complementa o adaptador atual, que já
contém o patch de menções. Validar com `git apply --check` antes de aplicar.

## Evidência de produção, somente leitura

Na conversa #9 (ID interno 15), foram encontrados dois registros:

- Message 382: áudio, conteúdo nulo, attachment 70, source_id
  `WAID:3EB02F024DE670B729284E`, status `sent`, mas external_error ainda
  `Net::ReadTimeout with #<TCPSocket:(closed)>`.
- Message 383: texto, nenhum attachment, source_id
  `WAID:3EB01954FF7B4183B72CF1`, status `sent`, sem erro.

O usuário confirmou a entrega de áudio e texto no telefone. O estado Vue, as
requisições do navegador e os eventos websocket desse envio não foram capturados
ao vivo; não foi reproduzida uma mensagem otimista combinada no código atual.
Não atribuir esse sintoma a uma causa não comprovada.

## Causa confirmada

`ChatwootImport.updateMessageSourceID` fazia SQL direto alterando source_id,
status, created_at e updated_at. Isso não passa pelos callbacks Rails, não limpa
external_error e não publica message.updated. Também muda a ordem cronológica:
o áudio confirmado mais tarde pode ficar com created_at posterior ao texto.

O webhook tem timeout padrão de cinco segundos. Se o envio demora, o Chatwoot
marca failed; a confirmação SQL posterior deixa o banco sent e a tela failed.

## Correção

O SQL mantém somente a associação do source_id. O adaptador então chama
`PATCH /api/v1/accounts/:accountId/conversations/:conversationId/messages/:id`
com `status: sent` e `external_error: null`, usando o cliente autenticado existente.
Isso reutiliza StatusUpdateService: limpa o erro, preserva delivered/read e
publica a alteração pelo fluxo nativo quando há mudança. Não afirma delivered.
Não altera created_at, não cria outra Message e não reenvia mídia.

No Chatwoot, um ReadTimeout posterior não sobrescreve uma Message outgoing já
confirmada com source_id e status não failed. A decisão ocorre sob o lock da
Message. Timeouts sem confirmação e rejeições HTTP reais continuam sendo erros.

Na UI, o áudio otimista usa o rótulo localizado de áudio, sem consumir o texto
capturado. O texto recebe outro echo_id. ADD_MESSAGE reconcilia e remove a cópia
que pode surgir quando um evento sem echo_id antecede a resposta de criação.
A resposta HTTP conserva o status retornado pelo servidor.
Uma resposta `sent` atrasada não rebaixa um `delivered`/`read` já recebido pelo
websocket. Falhas reais continuam sendo aplicadas.

## Verificações locais

- 27 testes focados passaram: 15 do composer e 12 de estado/reconciliação.
  Os métodos reais foram executados com dependências externas isoladas; não é
  uma execução completa da aplicação no navegador.
- ESLint passou nos arquivos JS/Vue alterados.
- O patch aplica limpo sobre os dois arquivos lidos da Evolution da VPS.
- Oito verificações isoladas do método real do adaptador passaram, sem API real.
- Oito verificações isoladas dos métodos Ruby reais passaram em container sem
  rede/banco: timeout antes/depois da confirmação, erro HTTP verdadeiro e
  preservação de delivered/read. Os specs Rails com banco não foram executados.

## Validação após deploy autorizado

Aplicar os dois lados em conjunto, por rebuild das imagens existentes. Preservar
ENV, redes, mounts, sessões e bancos. Não editar status manualmente para mascarar
o problema. Validar grupo/individual, áudio gravado/local, envio lento, websocket
atrasado e refresh; correlacionar exatamente duas Messages com os IDs WhatsApp.
O teste real e a confirmação visual continuam pendentes até esse deploy.
