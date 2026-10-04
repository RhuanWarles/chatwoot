# Auditoria Docker/Portainer — CRM v1.0.4

Data: 04/10/2026. Escopo: imagem publicada e arquivos de Docker Standalone/Compose deste repositório. Não houve push, publicação de nova imagem, acesso de deploy à VPS, alteração de produção ou execução de migrations em bancos existentes nesta auditoria.

## Veredito

**Stacks com preparação automática pelo serviço one-shot prepare, validadas sintaticamente com Compose v5.3.0. Não homologadas de ponta a ponta em uma instalação nova nem na versão específica do Portainer-alvo.** Web/worker aguardam prepare finalizar com sucesso. Instalação nova não requer comando manual de migration; atualização requer parar os serviços antigos pelo Portainer antes do Update.

**Problema bloqueante corrigido:** ambas as Stacks injetavam `DATABASE_URL: ''`. No Active Record 7.2.3.1 isso provoca `Database URL cannot be empty`. Removida essa entrada de `stack.yaml`, `stack.bundled.yaml` e `.env.example`. O guia foi corrigido. A reprodução em container temporário com a mesma versão do Active Record mostrou o erro com string vazia e resolução correta de `POSTGRES_HOST` quando a variável foi omitida. A correção é no ENV da Stack e não exige reconstruir v1.0.4.

## Evidências e limites dos testes

| Verificação | Resultado |
| --- | --- |
| Build completo publicado | Sucesso no [GitHub Actions](https://github.com/RhuanWarles/chatwoot/actions/runs/37186559952) |
| Imagem | `ghcr.io/rhuanwarles/chatwoot:v1.0.4` |
| Digest do índice OCI | `sha256:7e0a5429021a9f66fa62eec5ac84d0090d931bd17bda877b6b9ee0cc555609fa` |
| Plataforma | Linux amd64; ARM não incluído |
| Revisão na imagem | `518b1f6cdfda5ebbc18e158e8581f41fce355839` |
| Pull anônimo | Consulta do manifesto público confirmada; não exige Registry Credentials |
| Conteúdo real da imagem | Camada `/app` baixada no D: e digest da camada verificado, sem pull no Docker local |
| Migrations | Todas as 197 migrations do repositório presentes, conteúdo igual normalizando CRLF/LF; oito migrations do CRM |
| CRM | Modelos Deal, Activity e DealEvent e páginas CrmDeals/CrmDealDetails iguais ao código local auditado |
| Assets | Manifest Vite presente; 74 arquivos JS/CSS; nenhum arquivo referenciado pelo manifest ausente; dashboard compilado |
| Scripts | `rails.sh`, helper PostgreSQL e `bin/rails` presentes com permissão executável Unix |
| Compose | Ambos os YAMLs passam em `docker compose config`; Web/worker usam a mesma imagem; `DATABASE_URL` omitida |
| Variáveis obrigatórias | Ausência de `FRONTEND_URL` interrompe a interpolação antes do deploy |
| SSL do healthcheck | Middleware ActionDispatch::SSL 7.2.3.1: HTTP sem header retorna 301; header `X-Forwarded-Proto: https` retorna 200 |
| PostgreSQL healthcheck | `pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"` executado em leitura no PostgreSQL local já existente: accepting connections |
| Redis healthcheck | `--requirepass` + `REDISCLI_AUTH` + `redis-cli ping` testados em container temporário da imagem Redis local: sucesso |
| Diff | `git diff --check` sem erros |
| Subida integral da v1.0.4 | Não executada: Docker armazena dados no C:, com aproximadamente 490 MB livres; imagem ausente localmente |

Os testes isolados de Rails usaram a imagem de desenvolvimento já disponível, com Active Record/ActionDispatch 7.2.3.1, e não a imagem publicada inteira. O teste Redis também usou a imagem local disponível, sem baixar `redis:7-alpine`. Isso valida os mecanismos e não substitui a homologação da Stack completa. Os containers locais existentes foram preservados. Não foi feita limpeza de volumes/imagens nem movimentação do armazenamento Docker.

## Imagem e migrations

O Dockerfile instala gems, compila assets com `assets:precompile`, copia `/gems` e `/app` para a imagem final e fornece o mesmo runtime para Web e Sidekiq. Não depende do source, de `node_modules`, `.git` ou `.env` do host. As Stacks especificam comandos explicitamente: a imagem sozinha tem CMD `irb` e não inicia Rails automaticamente.

Migrations do CRM, em ordem:

1. `20261002000000_create_crm_tables`: pipelines, stages e deals.
2. `20261002010000_add_probability_to_crm_pipeline_stages`: probabilidade.
3. `20261002020000_create_crm_deal_events`: histórico/timeline e backfill de eventos de negócios existentes.
4. `20261002030000_create_crm_activities`: atividades.
5. `20261002040000_add_google_calendar_to_crm`: conexões Google e campos de reunião/sincronização.
6. `20261003010000_create_crm_custom_fields`: definições e valores dos campos personalizados.
7. `20261003020000_add_cancellation_details_to_crm_activities`: motivo, autor e data do cancelamento.
8. `20261003190000_add_crm_deal_search_indexes`: índices GIN de busca.

Nenhuma versão de migration duplicada encontrada. Não identifiquei dependência das migrations CRM em IDs, arquivos ou credenciais locais. O backfill lê os Deals do próprio banco. A migration de busca depende de `companies`, `contacts` e `pg_trgm`; estes constam do schema-base e das migrations anteriores. Ela usa índices concorrentes fora de transação; se interrompida, examine índices inválidos antes de tentar novamente.

`db/schema.rb` está na versão `20260930020000`, anterior ao CRM. **Carregar somente o schema não instala o CRM.** O task `db:chatwoot_prepare` carrega o schema-base e seeds quando não existe `ar_internal_metadata`, depois executa migrations pendentes. Em banco já preparado, executa migrations. Isso explica por que as tabelas CRM não precisam constar do snapshot antigo para esse procedimento funcionar.

As extensões do schema incluem `pg_stat_statements`, `pg_trgm`, `pgcrypto` e `vector`. A imagem PostgreSQL bundled é `pgvector/pgvector:pg16`; o usuário de inicialização tem permissão para preparar o banco. Em banco gerenciado externo, confirme disponibilidade e permissões para **todas** essas extensões. Não presuma que apenas pgvector seja suficiente.

## O que acontece ao clicar em Deploy

A stack bundled executa automaticamente: PostgreSQL/Redis healthy → prepare → Web/worker. `prepare` usa a mesma imagem, ENV e storage, `restart: 'no'`, `entrypoint: []` e apenas `bundle exec rails db:chatwoot_prepare`. O entrypoint da imagem não é necessário: as gems estão incluídas e a dependência garante PostgreSQL disponível. Web/worker mantêm seus comandos/entrypoint atuais e não executam migrations.

No Portainer Docker Standalone: Add stack → Web editor → colar YAML → preencher Environment → Deploy the stack → aguardar. Não há comando manual de preparação. Configure domínio/proxy/TLS previamente. `prepare` em **Exited (0)** significa sucesso. Se falhar, seus logs contêm o erro e novos Web/worker não iniciam. Corrija a causa e redeploye pelo Portainer; não ignore o erro.

Na app-only, provisionar PostgreSQL e Redis externos disponíveis antes do Deploy, com DNS, autenticação e rede corretos. Não há serviços locais nem healthchecks externos: a preparação falha se não conseguir acessar PostgreSQL. A saúde de Redis externo deve ser garantida pelo operador; o task não é uma probe completa de Redis.

Para atualizar: faça backup, suspenda tráfego e pare **Web e worker pelo Portainer**, mantendo banco/Redis. Troque `CHATWOOT_IMAGE` para uma nova tag publicada em Environment e clique Update the stack, solicitando pull da imagem. A mudança da imagem compartilhada recria `prepare`, que executa novamente antes da partida da aplicação. Preserve Stack, volumes e chaves. Uma atualização da mesma tag não comprova troca de imagem; use tags novas.

**Limitação:** `depends_on` controla a partida via Compose; não interrompe containers antigos já em execução durante migrations nem controla reinícios isolados do Docker. Por isso a parada de Web/worker pelo Portainer é necessária em atualizações, especialmente migrations incompatíveis. Não existem migrations no entrypoint para contornar essa limitação. Uma única Stack deve gerenciar o banco; stacks concorrentes não são serializadas por esse YAML.

Compose moderno suporta `service_completed_successfully`: https://docs.docker.com/compose/how-tos/startup-order/. O Portainer oferece Web editor/Environment para Docker Standalone: https://docs.portainer.io/user/docker/stacks/add. A versão específica do Portainer-alvo não foi testada; se rejeitar a condição, atualize para uma versão com suporte antes de usar. Não utilizar no Swarm.

## Conexões e healthchecks

- **PostgreSQL:** `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD` alimentam `config/database.yml`. `pg_isready` verifica aceitação de conexões, não valida senha, tabelas ou migrations. Senha alterada na Stack não muda a senha de um usuário num volume PostgreSQL já inicializado.
- **DATABASE_URL:** não deve existir vazia no ENV. Uma URL não vazia prevalece sobre os campos correspondentes de `database.yml`. Para banco externo com URI/TLS, adicione ao `environment: &app-env` de `stack.yaml` a linha `DATABASE_URL: ${DATABASE_URL:?Set a non-empty DATABASE_URL}` e configure uma URI válida, com usuário/senha codificados na URL. O helper do entrypoint extrai host/porta/usuário para a espera PostgreSQL. Prefira informar porta explicitamente. O cadastro no Portainer sozinho não injeta uma variável que o YAML não referencia.
- **Redis:** `lib/redis/config.rb`, `config/cable.yml` e a configuração Sidekiq passam `REDIS_PASSWORD` separadamente. `REDIS_URL=redis://redis:6379` com senha separada está correto; não precisa embutir a senha na URL. A probe autentica via `REDISCLI_AUTH` e exige PONG. AOF persiste dados em `/data`.
- **Web:** rota `GET /health` existe e responde JSON 200 sem autenticação. FORCE_SSL continua sendo middleware; o header HTTPS da probe evita redirecionamento. A probe não consulta tabelas, Redis ou jobs. Ela verifica liveness HTTP, não prontidão funcional completa.
- **Worker:** não há healthcheck explícito. Verifique processo, logs e consumo de um job de teste; `running` não comprova processamento.
- **Runtime:** o entrypoint executa `bundle install` em toda partida. O build inclui as gems; se o bundle estiver inconsistente, a partida pode depender de rede e falhar. Não encontrei essa falha no build publicado, mas ela precisa ser observada na homologação.

## Chaves e persistência

`SECRET_KEY_BASE` deve ser um segredo forte. Para instalação nova, no servidor:

```sh
docker run --rm --entrypoint ruby ghcr.io/rhuanwarles/chatwoot:v1.0.4 \
  -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Guarde o valor e reutilize entre Web/worker, atualizações e restaurações. Trocar invalida cookies/sessões e outros valores assinados/criptografados dependentes dessa chave. Rotação planejada é possível; troca arbitrária não é procedimento de update.

As três chaves Active Record são exigidas pelas Stacks. O core permite alguns recursos sem elas, mas este fork usa `encrypts` nos tokens Google Calendar e também em atributos de usuários/IA: omiti-las quebra recursos criptografados. Não são opcionais para uma instalação completa deste projeto. Não há requisito local que force exatamente 32 caracteres; use os valores fortes gerados pelo Rails, normalmente 32 caracteres aleatórios, ou gere três valores independentes assim:

```sh
docker run --rm --entrypoint ruby ghcr.io/rhuanwarles/chatwoot:v1.0.4 \
  -rsecurerandom -e '3.times { puts SecureRandom.alphanumeric(32) }'
```

As linhas correspondem, na ordem, a PRIMARY_KEY, DETERMINISTIC_KEY e KEY_DERIVATION_SALT. Também existe `bundle exec rails db:encryption:init`, conforme a [documentação Rails](https://guides.rubyonrails.org/active_record_encryption.html). Não use placeholders, não publique os valores e mantenha backup seguro. **Trocar essas chaves pode tornar tokens e dados existentes indecifráveis.** Preservar apenas o banco sem preservar as chaves não basta.

Para `ACTIVE_STORAGE_SERVICE=local`, `config/storage.yml` aponta para `/app/storage`. Web e worker compartilham `storage_data` nesse caminho. O named volume persiste em redeploy, desde que o nome seja preservado e o volume não seja removido. Não altere `STORAGE_VOLUME`, `POSTGRES_VOLUME` ou `REDIS_VOLUME` no update. Ambientes diferentes no mesmo host precisam de nomes diferentes. Backup PostgreSQL não inclui uploads: faça backup do storage também. Em S3, configure credenciais e backup do bucket.

## Variáveis exatas no Portainer

Para a **Stack bundled**, estas sete são obrigatórias pela interpolação:

```dotenv
FRONTEND_URL=https://seu-dominio.example
SECRET_KEY_BASE=<segredo-gerado>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<chave-gerada>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<outra-chave-gerada>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<salt-gerado>
POSTGRES_PASSWORD=<senha-forte>
REDIS_PASSWORD=<outra-senha-forte>
```

Opcionais, todas com defaults no YAML ou vazias para integrações não usadas:

```text
CHATWOOT_IMAGE
FORCE_SSL
ENABLE_ACCOUNT_SIGNUP
DEFAULT_LOCALE
POSTGRES_HOST
POSTGRES_PORT
POSTGRES_DATABASE
POSTGRES_USERNAME
REDIS_URL
ACTIVE_STORAGE_SERVICE
S3_BUCKET_NAME
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
MAILER_SENDER_EMAIL
SMTP_ADDRESS
SMTP_PORT
SMTP_DOMAIN
SMTP_USERNAME
SMTP_PASSWORD
SMTP_AUTHENTICATION
SMTP_ENABLE_STARTTLS_AUTO
SMTP_OPENSSL_VERIFY_MODE
GOOGLE_OAUTH_CLIENT_ID
GOOGLE_OAUTH_CLIENT_SECRET
WEB_BIND_ADDRESS
WEB_PORT
STORAGE_VOLUME
POSTGRES_VOLUME
REDIS_VOLUME
```

Defaults bundled: imagem v1.0.4, PostgreSQL `postgres:5432`, database `chatwoot`, usuário `postgres`, Redis `redis://redis:6379`, storage local, HTTPS obrigatório, signup público desabilitado, locale pt_BR, bind `127.0.0.1:3000`.

SMTP, S3 e OAuth deixam de ser opcionais para os respectivos recursos. Na Stack app-only, defina também os destinos reais PostgreSQL/Redis: defaults `postgres` e `redis` só funcionam se esses DNS forem resolvíveis na rede da aplicação. POSTGRES_VOLUME/REDIS_VOLUME não se aplicam à Stack app-only. `DATABASE_URL` não faz parte da lista padrão; requer a alteração explícita descrita acima.

## Primeiro deploy — banco novo

Siga o fluxo automático acima. Não execute db:chatwoot_prepare manualmente nem por múltiplos containers.

## Nginx no host

`127.0.0.1:3000:3000` é correto para Nginx instalado **no host da mesma VPS**. O upstream é `http://127.0.0.1:3000`; preserve os headers HTTPS e WebSocket:

```nginx
# Dentro do server HTTPS existente; certificados e server_name devem estar configurados.
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 300s;
}
```

Porta 3000 já usada no host: altere WEB_PORT e o upstream juntos. Nginx em container não acessa o host via seu próprio `127.0.0.1`: nesse cenário configure rede compartilhada explicitamente e use `web:3000`. A Stack não cria proxy, TLS ou DNS.

## Atualização

Siga o fluxo automático acima, parando Web/worker antigos pelo Portainer antes do Update. O prepare usa a imagem-alvo e aplica migrations antes dos containers novos.

## Rollback

Se schema continuar compatível com v1.0.4, pare tráfego/Web/worker, volte CHATWOOT_IMAGE para v1.0.4, faça pull e `up -d web worker` usando os mesmos nomes de projeto, volumes e segredos. Registre o digest anterior para rollback exato.

**Voltar a imagem não desfaz migrations.** As migrations CRM acrescentam tabelas/colunas/índices e o rollback dessas migrations remove dados; não execute `db:rollback` automaticamente. Não é possível declarar compatibilidade da futura v1.0.5 sem revisar suas migrations. Se houve remoção/renomeação de colunas ou mudança incompatível, restaure um backup compatível em procedimento planejado, considerando perda de dados gravados depois do backup. Nunca use `down -v`, reset de banco ou prune de volumes como rollback.

## Validar após instalação/update

```sh
docker compose -p chatwoot-crm --env-file .env -f stack.bundled.yaml ps
docker compose -p chatwoot-crm --env-file .env -f stack.bundled.yaml logs --tail 100 web worker postgres redis
curl -fsS -H 'X-Forwarded-Proto: https' http://127.0.0.1:3000/health
docker compose -p chatwoot-crm --env-file .env -f stack.bundled.yaml exec web bundle exec rails db:abort_if_pending_migrations
docker compose -p chatwoot-crm --env-file .env -f stack.bundled.yaml exec web bundle exec rails runner 'puts ActiveRecord::Base.connection.select_value("SELECT 1"); puts Crm::Pipeline.count; puts Crm::Deal.count; puts Crm::Activity.count; puts Crm::CustomField.count; puts Crm::DealEvent.count'
```

O runner imprime contagens, sem expor dados de contatos. Confira extensões pelo banco, execute onboarding/login via HTTPS, abra Kanban/Deal, crie um pipeline/negócio/atividade/anotação/campo personalizado de teste e confirme persistência/histórico após recarregar. Anexe um arquivo de teste, confira processamento pelo worker e persistência em redeploy. Google/Evolution/SMTP precisam de configuração própria; presença de código não confirma funcionamento dessas integrações.

Erros a investigar: Web/worker reiniciando, `Database URL cannot be empty`, `PG::UndefinedTable`, migrations pendentes, autenticação PostgreSQL/Redis, chaves ausentes/alteradas, assets inexistentes, loop de redirect HTTPS, worker sem consumo, volume novo por nome errado. `/health` verde não exclui esses problemas.

## Compatibilidade e riscos restantes

Anchors YAML, `${VAR}`, `${VAR:?message}`, named volumes, healthcheck e `depends_on: condition: service_healthy` são suportados pelo Compose moderno usado no modo Standalone. A validação local foi com Docker Compose v5.3.0, não com uma versão específica do Portainer instalado pelo usuário. [Portainer documenta Web editor e Environment](https://docs.portainer.io/user/docker/stacks/add); [Docker documenta dependências saudáveis](https://docs.docker.com/compose/how-tos/startup-order) e [interpolação obrigatória](https://docs.docker.com/reference/compose-file/interpolation/). Não usar estes YAMLs como Docker Swarm Stack; `depends_on` não fornece essa garantia em Swarm.

Não houve mudança de visibilidade GHCR. Se uma futura imagem for privada: em Portainer → Registries → Add registry, configure `ghcr.io`, usuário GitHub e token com `read:packages` e eventual autorização SSO; selecione a credencial no deploy. Não faça isso para v1.0.4 pública sem necessidade.

Riscos ainda não eliminados: primeira preparação real e subida completa da imagem publicada; recursos RAM/disco do host-alvo; versão real do Portainer/Compose; extensões em banco gerenciado; TLS/proxy; processamento Sidekiq; uploads; login/onboarding; integrações externas e compatibilidade de futuras migrations. Esta auditoria não declara esses testes como concluídos.
