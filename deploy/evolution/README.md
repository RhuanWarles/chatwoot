# Menções reais em grupos — Evolution 2.3.7

Esta alteração **não cria nem instala uma stack**. O patch acompanha o código do
Chatwoot porque o webhook nativo da Evolution 2.3.7 ignora metadata de menções.
As duas partes precisam ser aplicadas juntas, somente após autorização de deploy.

## Fluxo confirmado na instalação atual

`Chatwoot → POST /chatwoot/webhook/Rhuan → ChatwootService → textMessage(data, true)`

Não há n8n intermediando esse envio. O endpoint público equivalente para texto é
`POST /message/sendText/{instance}`. Seu campo é `mentioned: string[]`, na raiz do
body, conforme `SendTextDto`, `textMessage` e `sendMessageWithTyping` do source map
da versão instalada. O webhook chama esse método internamente; não faz outra
requisição HTTP ao endpoint de texto.

`createJid` preserva tanto `@lid` quanto `@s.whatsapp.net`. Usamos o `lid` retornado
para o participante do grupo, quando disponível; caso contrário, o `jid`. Nunca
deduzimos o identificador pelo nome.

## Payload

Antes, o adaptador criava um `SendTextDto` contendo apenas `number`, `text`,
`delay` e `quoted`:

```json
{"number":"120363000000001@g.us","text":"Oi @Fernando Murilo"}
```

Com a alteração, o conteúdo armazenado no Chatwoot continua sendo
`Oi @Fernando Murilo`, com identidade e posição em
`message.content_attributes.whatsapp_mentions`:

```json
{
  "whatsapp_mentions": [{
    "start": 3,
    "end": 19,
    "lid": "247613823709228@lid",
    "jid": "5519994212713@s.whatsapp.net",
    "phone": "5519994212713",
    "display_name": "Fernando Murilo"
  }]
}
```

Esses identificadores são exemplos. `start`/`end` são posições de caracteres
Unicode, com o final exclusivo. O backend valida o trecho e a participação no
grupo da Conversation autorizada; a identidade canônica vem desse grupo.

Somente no payload de entrega, o nome vira `@` + a parte numérica do identificador.
O adaptador passa a montar:

```json
{
  "number":"120363000000001@g.us",
  "text":"Oi @247613823709228",
  "mentioned":["247613823709228@lid"]
}
```

`delay`, assinatura e `quoted` existentes são preservados. A Evolution converte
`mentioned` em `contextInfo.mentionedJid` por meio do fluxo nativo do Baileys.
Participantes repetidos são deduplicados na lista de identificadores, mantendo
todas as ocorrências no texto. Sem menções, o payload anterior permanece igual.
O patch também repassa `mentioned` para legendas pelo fluxo de mídia existente;
não modifica a implementação de áudio.

## Aplicação posterior, após autorização

O arquivo `patches/chatwoot-group-mentions-v2.3.7.patch` foi gerado e validado contra
o código exato do container `evoapicloud/evolution-api:v2.3.7` instalado. Ele altera
somente `src/api/integrations/chatbot/chatwoot/services/chatwoot.service.ts`.

No checkout correspondente da Evolution, verificar antes de aplicar:

```sh
git apply --check /caminho/chatwoot/deploy/evolution/patches/chatwoot-group-mentions-v2.3.7.patch
git apply /caminho/chatwoot/deploy/evolution/patches/chatwoot-group-mentions-v2.3.7.patch
```

Rebuildar a imagem da Evolution a partir desse código e atualizar somente seu
serviço, preservando banco, mounts, sessões, ENV e todas as networks existentes.
Atualizar também o código/imagem do Chatwoot na instalação existente. Não aplicar
somente o lado Chatwoot em produção: a Evolution sem o patch continuará ignorando
as menções. Não editar o JavaScript minificado dentro do container em execução.

## Aceite pendente de teste real

Após aplicar ambos os lados, enviar pelo composer uma mensagem de grupo com uma
menção e outra com duas. Conferir no resultado da Evolution o
`extendedTextMessage.contextInfo.mentionedJid`, correlacionar o ID com o
`source_id` da Message e verificar a menção clicável no WhatsApp do destinatário.
Confirmar também o comportamento de notificação no dispositivo mencionado.

Repetir apagando a menção antes de enviar, digitando apenas o nome manualmente e
enviando uma mensagem comum em conversa individual. Conferir que o Chatwoot
continua exibindo o nome humano e que não há envio duplicado.

Um HTTP 200, isoladamente, **não encerra o aceite**. Sem autorização para deploy,
nenhuma mensagem de teste será disparada em produção. A integração de metadata
inbound será avaliada depois da confirmação real do outbound.

## Arquivos da implementação

- `app/javascript/dashboard/components/widgets/WootWriter/Editor.vue`: seleção como
  entidade atômica; nome legível na seleção/cópia de texto.
- `app/javascript/dashboard/helper/groupMentionHelper.js`: identidade nos rascunhos,
  serialização e posições Unicode; metadata desaparece ao apagar a entidade.
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`: payload
  com menções; contador considera texto visível e rascunhos preservam a identidade.
- `app/builders/messages/message_builder.rb`: validação antes de salvar a Message.
- `app/services/messages/group_mentions_validator.rb`: valida tipo, intervalos,
  grupo e pertencimento do participante, a partir da Conversation da account.
- `app/presenters/message_content_presenter.rb`: conversão de nome para identificador
  somente no conteúdo entregue pelo webhook; Message original mantém nome humano.
- `config/locales/en.yml` e `config/locales/pt_BR.yml`: erro de validação em i18n.
- `app/javascript/dashboard/helper/specs/groupMentionHelper.spec.js` e
  `spec/services/messages/group_mentions_validator_spec.rb`: cobertura de regressão.
- `deploy/evolution/patches/chatwoot-group-mentions-v2.3.7.patch`: ajuste do adaptador
  nativo da Evolution; nenhuma mudança de banco, sessão ou configuração.

## Validação realizada antes do deploy

- Nove testes do editor passaram: uma e duas identidades, nomes iguais, remoção,
  texto digitado manualmente, rascunho, emoji, somente JID e nomes especiais.
- Treze verificações do backend passaram em um processo Rails separado, usando a
  Conversation real e Messages **não salvas**. Nenhuma escrita no banco ou envio
  ao WhatsApp. Inclui metadata inválida, notas privadas, conversa individual,
  atributos multipart e preservação do conteúdo humano.
- Sete verificações do código extraído do patch passaram, incluindo deduplicação,
  grupo, conversa individual, JID alternativo e ausência de menções.
- Scripts e templates dos dois componentes Vue compilaram; `git diff --check` e
  `git apply --check` passaram.
- A suíte RSpec adicionada ainda precisa ser executada em ambiente de testes com
  banco próprio. O teste real de entrega, renderização e notificação no WhatsApp
  permanece pendente. Não houve push, deploy, restart nem instalação de stack.
