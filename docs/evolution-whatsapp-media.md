# Diagnóstico de mídia WhatsApp → Evolution → Chatwoot

Data: 06/10/2026. Evolution em execução: `evoapicloud/evolution-api:v2.3.7`.

**Atualização de produção:** após autorização explícita do usuário, a diretiva foi aplicada em `/etc/nginx/conf.d/90-chatwoot-evolution-headers.conf`. `nginx -t` passou e o reload gracioso foi concluído em 06/10/2026 às 18:08:40 (America/Sao_Paulo). O GET público com somente api_access_token passou de 401 para 200; o GET com Bearer permaneceu 200. Isso confirma o Nginx como o ponto que descartava o header. Nenhum container foi reiniciado. Novos testes de mídia ainda são necessários para validar anexos e reprodução; não declarar toda a integração resolvida somente pelo GET.

## Causa comprovada

Os arquivos chegam à Evolution e são gravados na tabela Message dela. No caminho de mídia, `ChatwootService.sendData` envia multipart ao Chatwoot usando somente o header `api_access_token`. O proxy público não preserva esse header com underscore; Rails não reconhece autenticação por API e interrompe em `authenticate_user!` com HTTP 401, antes de MessageBuilder/Attachment/ActiveStorage.

Texto usa `createMessage` via `@figuro/chatwoot-sdk`. O SDK envia **Authorization: Bearer** e também api_access_token. Por isso texto continua funcionando com a mesma credencial.

Teste de leitura realizado com a credencial já salva, usando Axios dentro da Evolution, sem imprimir o token:

| Requisição GET à conversa 13 | Resultado |
| --- | --- |
| Domínio público + api_access_token | 401: exige login |
| Mesmo domínio + Authorization: Bearer | 200 |
| DNS Docker interno + api_access_token + X-Forwarded-Proto=https | 200 |

Nginx do Chatwoot não possui `underscores_in_headers on`; o default é off, conforme [documentação oficial](https://nginx.org/en/docs/http/ngx_http_core_module.html#underscores_in_headers). O teste localiza a perda na cadeia pública de proxy; após habilitar a diretiva, repetir o GET confirma se o Nginx era o ponto exato ou se ainda existe filtragem anterior no Cloudflare. Nenhum token foi considerado inválido ou rotacionado.

A tentativa de multipart chega ao Rails, que retorna 401 sem consultas ao banco. Não é uma falha de player, thumbnail, serializer ou falta de permissão no volume. Não foi encontrado erro 500 como causa dessas tentativas; houve também retry de download de um sticker, um evento separado.

## Instância atual

- `Rhuan`: conectada, Chatwoot habilitado, account 1, inbox `rhuan` ID 9.
- `rwhub`: conectada, porém integração Chatwoot desabilitada.

Novos testes devem usar o telefone da instância **Rhuan**, não rwhub. Não foram alterados nomes, configurações, sessões ou bancos.

## Payloads reais, sanitizados

Campos de transporte/chaves criptográficas, URLs temporárias, conteúdo pessoal e telefone removidos. Os IDs abaixo são de registros reais encontrados no PostgreSQL da Evolution.

Imagem recebida em grupo:

```json
{
  "key": {
    "id": "3EB048C0AB1E127EE87BF5",
    "fromMe": false,
    "remoteJid": "[grupo]@g.us",
    "participant": "[participante]@lid",
    "participantAlt": "[telefone]@s.whatsapp.net",
    "addressingMode": "lid"
  },
  "messageType": "imageMessage",
  "message": {
    "imageMessage": {
      "mimetype": "image/jpeg",
      "mediaKey": "[removida]",
      "directPath": "[removido]"
    }
  },
  "chatwootMessageId": null
}
```

Voice note recebida:

```json
{
  "key": {
    "id": "3EB0A3758C6CC7EF8F9AFE",
    "fromMe": false,
    "remoteJid": "[contato]@lid",
    "remoteJidAlt": "[telefone]@s.whatsapp.net",
    "addressingMode": "lid"
  },
  "messageType": "audioMessage",
  "message": {
    "audioMessage": {
      "mimetype": "audio/ogg; codecs=opus",
      "ptt": true,
      "seconds": 9,
      "mediaKey": "[removida]",
      "directPath": "[removido]"
    }
  },
  "chatwootMessageId": null
}
```

Outros exemplos sem registro equivalente no Chatwoot:

| ID Evolution | Tipo | fromMe |
| --- | --- | --- |
| 3A9B06FB98F554B49212 | audioMessage, OGG/Opus, PTT | true |
| 3AD64F7F0C06EC8FF598 | audioMessage em grupo, OGG/Opus | true |
| 4ACCB7D6B694FF2E2BE2 | imageMessage, JPEG | true |
| 2A4BE5EEBCCE5A36F847 | videoMessage, MP4 | false |
| 3AF23501240F234BE8C7 | videoMessage, MP4 | true |

Não foi validado um documento real nesta rodada. A mensagem única MEDIA-TRACE-001 ainda não havia sido localizada ao concluir a coleta inicial. Os exemplos acima são eventos reais anteriores; não foram gerados ou reenviados pelo diagnóstico.

## Download e normalização existentes

Código auditado a partir do sourcemap da **imagem em execução**, não apenas da branch main upstream:

- `src/api/integrations/chatbot/chatwoot/services/chatwoot.service.ts`: `createMessage`, `sendData`, `isMediaMessage` e ramo de eventos de mídia.
- `src/api/integrations/channel/whatsapp/whatsapp.baileys.service.ts`: `getBase64FromMediaMessage`.
- `node_modules/@figuro/chatwoot-sdk/dist/core/request.js`: headers do SDK.

O detector lista imageMessage, documentMessage, documentWithCaptionMessage, audioMessage, videoMessage, stickerMessage e viewOnceMessageV2. O downloader desempacota os subtipos configurados, seleciona o conteúdo de mídia, usa `downloadMediaMessage` do Baileys com suporte de reupload e devolve base64, MIME, nome e tamanho. Em falha, aguarda cinco segundos e tenta `downloadContentFromMessage` com mediaKey/directPath. Não é um download comum da URL WhatsApp criptografada.

O fluxo Chatwoot decodifica o base64 em Buffer/Readable, gera filename e envia `attachments[]`, message_type, caption quando existe, source_id `WAID:<id>` e referência à resposta. Não salva a URL temporária como anexo permanente. A conversão de áudio para MP4 é opt-in; esse ramo da integração não solicita conversão. Não é necessário criar um novo downloader nem converter OGG por causa do 401.

Wrappers ephemeral/view-once/document-caption precisam de amostras reais antes de declarar cobertura completa: o detector de mídia da integração não lista todos os wrappers explicitamente. Não foi aplicado patch especulativo de normalização.

## Attachment e UI nativos

Depois de autenticar, MessagesController chama `Messages::MessageBuilder`. O builder prepara a Message com account/conversation, constrói seus Attachments com o mesmo account_id e arquivo multipart, determina file_type pelo MIME e salva a Message com autosave dos anexos. ActiveStorage faz persistência do arquivo após commit. Não foi criado sistema paralelo de anexos.

O serializer entrega `attachments` por `Attachment#push_event_data`, com id, message_id, account_id, file_type, data_url, content_type e metadados. O componente nativo de áudio consome esse attachment. Para voice note, o builder aceita `is_voice_message`; o multipart atual da Evolution não encaminha a flag PTT por esse campo. Isso não explica o 401 e não foi alterado.

Na coleta, existiam apenas três anexos no Chatwoot: uma imagem PNG e dois MP3. Os exemplos WhatsApp citados não tinham chatwootMessageId e não haviam criado novos Attachments. Por isso não foi possível validar reprodução OGG desses eventos na UI.

Storage real: local. Web e Sidekiq compartilham o named volume `chatwoot-saas-ai_storage_data` em `/app/storage`. Não foi reiniciado serviço para testar persistência; a configuração é persistente por volume. A leitura/gravação e a URL dos novos anexos precisam ser confirmadas após desbloquear a autenticação.

Foi verificado em leitura que os arquivos dos três blobs existentes estão presentes fisicamente no volume. Isso confirma os anexos anteriores; não prova que os novos arquivos WhatsApp já foram gravados.

## Idempotência, fromMe e grupos

`sendData` consulta source_id existente quando CHATWOOT_IMPORT_DATABASE_CONNECTION_URI está disponível; essa variável está configurada na Evolution atual. O Chatwoot possui índice não único em messages.source_id. Logo, não se pode afirmar exclusão de duplicatas concorrentes somente pela presença do índice. Replay e entrega duplicada devem ser testados após corrigir o header; não foi reexecutado evento real automaticamente.

Também foram encontrados dois source_ids já duplicados no mesmo account/conversation: mensagens 173/174 (conversa interna 20) e 112/113 (conversa interna 30). Não foram apagadas ou alteradas. A coleta não comprovou se vieram de replay, importação ou concorrência. Isso impede declarar o requisito de idempotência como validado, mesmo após corrigir o 401.

O código mapeia fromMe=false para incoming e true para outgoing, com o mesmo envio multipart. Grupos possuem ramo dedicado, resolvendo participantAlt para @lid e preservando identificação do remetente na legenda textual. Os exemplos de áudio/imagem enviados pelo telefone e mídia de grupos estão persistidos na Evolution, mas não no Chatwoot. Funcionamento após correção ainda não comprovado; não classificar como resolvido antes do teste final.

## Correção mínima aplicada após autorização

Arquivo local: `deploy/production/nginx/evolution-media-headers.conf`.

```nginx
underscores_in_headers on;
```

Incluir no **contexto http** do Nginx, por exemplo pelo include existente de conf.d/*.conf. Esse contexto evita a dependência da ordem do header Host/default server na interpretação inicial dos headers. A mudança permite headers com underscore nos virtual hosts atendidos por esse Nginx; não desabilita autenticação ou permissões do Chatwoot.

Foi verificado o include efetivo de conf.d no contexto http. A cópia de segurança do nginx.conf ficou em `/home/deploy/.cache/chatwoot-media-fix/20261006T210822Z/nginx.conf.before`, com acesso restrito. O arquivo novo não existia antes e contém somente comentário e a diretiva. A configuração passou em `nginx -t`; após reload, o GET público com api_access_token retornou 200. Não houve necessidade de alterar Cloudflare, tokens, código Rails ou Evolution.

O usuário deploy não dispõe de sudo sem senha. A validação/reload usou o acesso Docker administrativo existente em helpers temporários, removidos ao terminar. Para o reload foi necessário desativar AppArmor somente nesse helper, permitindo sinalizar o Nginx do host; os serviços existentes mantiveram sua configuração de segurança. O host foi montado somente leitura, exceto os arquivos operacionais de PID/log necessários ao Nginx; a escrita de configuração foi limitada a conf.d. Não foram usados containers privilegiados nem reiniciados os serviços de aplicação.

Rollback desta correção: remover somente `/etc/nginx/conf.d/90-chatwoot-evolution-headers.conf`, validar com nginx -t e fazer reload. Isso restabelece o comportamento anterior e pode fazer a mídia voltar a receber 401; não envolve banco ou volumes.

Alternativa no código Evolution: adicionar Authorization: Bearer no multipart, mantendo api_access_token e reutilizando a credencial salva. Exigiria preparar e publicar imagem Evolution própria/redeploy; não foi escolhida nesta etapa. Alterar URL para HTTP Docker interno também exige revisar FORCE_SSL e redirects; não foi aplicado como atalho.

## Validação pendente após aplicação

1. Texto recebido continua funcionando.
2. Imagem com legenda MEDIA-TRACE-001 recebida em Rhuan: identificar ID Evolution → source_id → Message → Attachment → blob → resposta API → preview.
3. Voice note recebida: MIME OGG/Opus, anexo de áudio e reprodução no navegador.
4. Imagem/áudio enviados pelo telefone conectado: fromMe=true/outgoing.
5. Documento e vídeo reais: filename/MIME/tamanho e download/renderização.
6. Imagem/áudio em grupo: conversation e remetente corretos.
7. Mesmo evento duplicado: apenas uma Message/Attachment, incluindo risco concorrente.
8. Confirmar HTTP sem 401/500 e persistência após restart/redeploy somente quando autorizado.

Nenhum código do CRM, AI Agents, gravador de áudio, frontend ou model de anexos foi alterado. Não houve push, replay, envio de mensagem pelo agente ou restart de containers. A única mudança de produção autorizada foi a configuração Nginx descrita acima e seu reload. Solicitado novo teste com legenda MEDIA-TRACE-002 e voice note na instância Rhuan; ainda pendente de envio/validação.
