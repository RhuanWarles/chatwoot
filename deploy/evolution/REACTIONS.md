# Reações de grupos — Chatwoot + Evolution 2.3.7

Esta feature precisa dos **dois lados**. Atualizar somente o Chatwoot não corrige
o adaptador antigo, que transforma emojis em mensagens comuns e ignora remoções.
Não instalar uma stack nova. Não substituir a Evolution por uma imagem upstream
sem os patches deste fork: isso perderia menções, áudio e confirmação de envio.

## Contrato e persistência

O evento real `messages.upsert`/`send.message` contém `body.key` (evento/remetente)
e `body.message.reactionMessage` com `key` (mensagem alvo), `text` e
`senderTimestampMs`. O timestamp pode ser um protobuf Long; o adaptador converte
com `Long.fromValue(...).toNumber()`. `text: ''` significa remoção.

O patch intercepta reações **antes de criar Conversation ou Message**. Procura a
mensagem original no banco da Evolution pelo ID, grupo e instanceId e usa seu
`chatwootConversationId` para chamar:

`POST /api/v1/accounts/:account_id/conversations/:display_id/reaction_events`

Além do token Chatwoot já configurado, usa o header privado
`X-Evolution-Reaction-Key`, com a chave global da Evolution. O Chatwoot compara
esse header a `EVOLUTION_API_KEY`; as duas configurações devem corresponder.
Nenhuma chave entra em serializers, additional_attributes, Git ou frontend.
Não registrar headers em logs. Configure filtros de parâmetros/logs também no proxy.

O Chatwoot encontra a mensagem por `source_id`, aceitando o ID original ou
`WAID:<id>`, somente na Conversation e Account autorizadas. Alvo sem mapeamento
na Evolution ou não encontrado no Chatwoot é ignorado, com log técnico sem texto.
Não tenta adivinhar pelo conteúdo nem cria mensagem de fallback.

O estado fica em `Message.content_attributes.whatsapp_reactions`, já incluído na
API/realtime. Não há tabela/migration nova nem N+1: a leitura usa a própria
Message. A alteração usa lock da mensagem; uma identidade tem no máximo um
registro. LID/JID conhecidos são reconciliados pelo resolver de participantes.
Remoções ficam como tombstones (`emoji: ''`) e timestamps anteriores são
ignorados. O frontend agrega emoji/quantidade e omite tombstones.

Somente `message.reaction_updated` é disparado no backend; o ActionCable converte
para a atualização existente da bolha. Não há `message.created`, callback de
mensagem, webhook de entrega, unread, mudança de last_activity, IA/RAG/Tools,
memória, geração ou débito de crédito por esse caminho.

Para envio, o frontend chama:

`POST /api/v1/accounts/:account_id/conversations/:display_id/messages/:id/reaction`

O backend usa `POST /message/sendReaction/:instance`, com `{ key, reaction }`.
Antes do envio, lê `GET /chatwoot/find/:instance` e exige que `accountId` e `url`
correspondam à Account da mensagem e ao `FRONTEND_URL` desta instalação. Assim,
um nome de instância de outra Account não autoriza ações em seu WhatsApp.
Chaves de mensagens antigas são consultadas com `POST /chat/findMessages/:instance`;
o ID e remoteJid retornados precisam corresponder à mensagem/grupo. Falha não
altera o estado persistido; a UI restaura a reação anterior. Reações de outras
pessoas não podem ser removidas. Reações 1:1 são ignoradas pelo novo encaminhamento;
esta primeira versão não oferece UI de reações em conversas individuais.

**Limite do WhatsApp:** operadores da mesma instância compartilham um único número
WhatsApp. Não existem várias reações independentes desse número na mesma
mensagem. A última troca substitui a anterior e guarda o operador responsável.
Um operador não pode remover uma reação atribuída a outro operador. Eventos
fromMe do dispositivo sem operador conhecido representam a conta conectada.

## Preflight e publicação

1. Confirmar worktree limpo, branch, HEAD e diff. Publicar commit completo por
   push normal, sem force. Manter imagem atual e uma anterior validada.
2. No Chatwoot, usar somente `/home/deploy/chatwoot-saas-ai-clean`; fetch e
   atualização fast-forward para o commit publicado. Nunca overlay parcial.
3. Conferir `df -h`, `docker system df`, `docker buildx du`. Com >=5 GB, seguir;
   com 4–5 GB, somente sem mudança de dependências, com cache e monitoramento;
   abaixo de 4 GB, parar e revisar limpeza segura. Não apagar volumes/networks.
4. Build completo do Chatwoot, preservando cache:

```bash
cd /home/deploy/chatwoot-saas-ai-clean
docker build --build-arg SOURCE_REVISION="$(git rev-parse HEAD)" \
  -f docker/Dockerfile -t chatwoot-saas-ai:production .
cd /home/deploy/chatwoot-saas-ai
docker compose -f compose.yaml up -d --no-deps --no-build rails sidekiq
```

5. Aguardar boot e HTTP 200 no upstream e domínio **antes** de habilitar o novo
   adaptador. Não há migration desta feature. Não executar testes contra banco
   de produção, `db:drop`, `db:reset` ou `schema:load` em produção.
6. Na Evolution, usar source da versão 2.3.7 com os patches anteriores já
   aplicados. O patch de reações foi gerado contra o adaptador instalado cujo
   SHA256 era `588e8008ad7225e2a2eaa1bc1a86a1c8e35c4c51be120be5c1b275775c0dd3f2`.
   Conferir versão e diff; se divergir, revisar/adaptar antes, sem sobrescrever.

```bash
# No source de build da Evolution, separado do checkout antigo do Chatwoot:
git apply --check /home/deploy/chatwoot-saas-ai-clean/deploy/evolution/patches/chatwoot-group-reactions-v2.3.7.patch
git apply /home/deploy/chatwoot-saas-ai-clean/deploy/evolution/patches/chatwoot-group-reactions-v2.3.7.patch
# Usar o Dockerfile/build existente com todas as alterações anteriores.
docker build -t evolution-api:group-reactions .
```

O source da Evolution usa LF. O arquivo `.patch` também deve ser transferido
com LF; uma conversão CRLF feita pelo checkout Windows faz `git apply`/`patch`
falhar mesmo quando o conteúdo está correto. Normalize somente o patch (não o
projeto inteiro), valide com `patch --dry-run -p1` e só então aplique.

7. Recriar **somente Evolution** para trocar sua imagem, mantendo integralmente
   ENV, mounts, ports, networks/aliases, restart policy, labels, comando e
   entrypoint da instalação. Nunca executar `docker rm -v`. Guardar a imagem
   anterior e configuração em local privado fora de Git; não imprimir secrets.
   Verificar mounts/sessões antes de iniciar. Não fazer rollback automático.
   Para uma instalação standalone, usar o helper revisado abaixo. Ele cria e
   verifica um candidato antes de parar o atual; mantém o container anterior
   parado como backup e não imprime ENV/secrets. Rejeita configurações que
   exigem revisão adicional, como Compose, IP estático e VolumesFrom.

```bash
python3 /home/deploy/chatwoot-saas-ai-clean/deploy/evolution/recreate-container.py \
  --container evolution-api --image evolution-api:group-reactions
# Somente se o preflight estiver coerente:
python3 /home/deploy/chatwoot-saas-ai-clean/deploy/evolution/recreate-container.py \
  --container evolution-api --image evolution-api:group-reactions --apply
```

   Se falhar, parar: o helper não reinicia o backup automaticamente. O nome do
   backup é mostrado no resultado para recuperação manual deliberada. Nunca
   iniciar simultaneamente dois containers Evolution usando a mesma sessão.

   **Particularidade da VPS auditada:** os labels da Evolution apontam para um
   Compose temporário em `/tmp/evolution-config-*/docker-compose.yml` que já não
   existe. Não recriar esse Compose com valores adivinhados. Depois de confirmar
   ausência de todos os arquivos indicados pelos labels, o helper permite
   `--allow-missing-compose-source` no preflight e no `--apply`. Ele copia a
   configuração real do container e preserva seus labels/projeto existentes.
   Esse flag não aceita um Compose cujo arquivo ainda exista. Se o manifesto
   existir, atualizar apenas sua imagem e usar seu serviço original.
8. Confirmar instanceName correto e conexão `open`, sem solicitar novo QR code.
   Se sessão, mounts ou configurações divergirem, parar e reportar.

## Smoke obrigatório

Usar somente o grupo de teste autorizado. O teste desta entrega foi solicitado
para Account 1 / Conversation **#36**; esse destino não é configuração do produto.

- Receber reação real, depois trocar e remover; conferir a mesma bolha sem nova
  mensagem e sem alteração de contadores/preview/IA/usage.
- Enviar reação pelo Chatwoot; conferir no WhatsApp; trocar e remover. Conferir
  operador, lista de participantes, LID, realtime sem F5 e falha/optimistic.
- Duplicatas e evento antigo não devem restaurar emoji removido.
- Conferir texto, mídia, quote/reply, menções e conversa individual.
- Validar HTTP 200 e restart counts de Rails/Sidekiq/Evolution e serviços
  preservados. Não considerar só HTTP 200 como confirmação ponta a ponta.

Depois do smoke, revisar imagens sem containers, preservar produção e uma
imagem anterior válida por serviço. Remover somente gerações redundantes por
IDs revisados. Preservar cache útil Bundler/pnpm/base e não usar prune genérico.

## Testes

Backend: `spec/services/evolution/message_reactions_service_spec.rb` e
`spec/requests/api/v1/accounts/message_reactions_spec.rb`, em banco isolado local.
Frontend: `app/javascript/dashboard/components-next/message/specs/MessageReactions.spec.js`.
Validar também o patch/contrato da Evolution, seu build e o smoke real acima.
