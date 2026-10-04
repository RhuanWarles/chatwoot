# Release CRM v1.0.0: GHCR e Portainer

Este pacote reutiliza `docker/Dockerfile`. A mesma imagem executa Web e Sidekiq. Os arquivos abaixo destinam-se a **Portainer com Docker Standalone / Compose v2**, não a Docker Swarm. O código da VPS foi incorporado como snapshot sem novas regras de produto. A instalação existente não foi redeployada.

## Arquivos e requisitos

- `stack.bundled.yaml`: instalação nova com PostgreSQL 16/pgvector, Redis 7, Web e worker.
- `stack.yaml`: Web e worker para PostgreSQL/Redis já disponíveis.
- `.env.example`: variáveis de exemplo; no Portainer são variáveis da Stack, sem dependência de arquivo `.env` no host.
- `../../docker/Dockerfile`: Ruby 3.4.4, Node 24, pnpm 10.2.0, gems e assets compilados.
- `../../.github/workflows/crm-image.yml`: build linux/amd64; publicação exclusivamente ao enviar tag `vX.Y.Z`.

Imagem proposta: **`ghcr.io/rhuanwarles/chatwoot:v1.0.0`**. Ela ainda não foi publicada. Não usar a imagem oficial pura ou `latest` como referência de release. Para ARM, preparar/testar build adicional antes de usar; o workflow inicial publica apenas amd64.

`v1.0.0` versiona este CRM/fork, não substitui a versão upstream registrada em `VERSION_CW`/`package.json`.

## 1. Revisão antes da tag

Confira `git status`, `git diff` e o [changelog](../../CHANGELOG.md). As mudanças de produto já em execução na VPS precisam entrar no commit junto ao empacotamento; não descarte arquivos não commitados. Nenhuma credencial da VPS deve entrar na árvore Git ou no contexto de build.

O Dockerfile escreve `.git_sha` a partir de `SOURCE_REVISION`, aceita `CRM_VERSION` e não precisa copiar `.git` para a imagem. Normaliza scripts recebidos com CRLF. O build é feito do código completo; não usa uma camada improvisada sobre a imagem de produção da VPS.

Antes de publicar, faça build completo e teste login, Kanban, Deal, campos inline, Activities, histórico e integração configurada num ambiente separado. O rótulo v1.0.0 não substitui homologação. As bases Docker e repositórios de pacotes usam tags: a mesma tag de source não garante bytes idênticos em rebuilds futuros. Depois de publicar, registre o digest e use-o para pinning quando precisar de identidade exata.

## 2. Build local sem publicar

Linux/WSL com Docker disponível, na raiz do projeto:

```sh
REVISION=$(git rev-parse HEAD)
docker build --check -f docker/Dockerfile .
docker build -f docker/Dockerfile \
  --build-arg SOURCE_REVISION="$REVISION" \
  --build-arg CRM_VERSION=v1.0.0 \
  -t ghcr.io/rhuanwarles/chatwoot:v1.0.0 .
```

Não fazer build pesado na VPS com pouco disco/RAM. O build usa lockfiles, mas precisa acessar os repositórios Ruby/Node/Alpine. Não passe segredos de produção como build args. Instalações reais recebem ENV somente em runtime.

## 3. Criar commit/tag e publicar — executar somente após aprovação

O preparo não executa os comandos abaixo. Na branch desejada:

```sh
git status --short
git diff --check
# Revise todos os arquivos; não inclua .env real, dumps ou chaves.
git add .
git commit -m "release: CRM v1.0.0"
git tag -a v1.0.0 -m "CRM v1.0.0"
git push origin feat/saas-ai-usage
git push origin v1.0.0
```

Verifique se `v1.0.0` já existe antes de criá-la. Não mover tags de release publicadas. O workflow usa `GITHUB_TOKEN`, `contents: read` e `packages: write`, publica `v1.0.0` e `sha-<commit-completo>`, preserva o código do fork e não chama Portainer. Os workflows herdados de publicação DockerHub foram limitados ao upstream `chatwoot/chatwoot`, evitando publicação paralela errada neste fork.

No GitHub, habilite Actions e confira permissão de escrita em Packages. Para repositórios/organizações com restrições, conceda acesso do workflow ao pacote. A visibilidade inicial do pacote pode exigir ajuste no GHCR. Aguarde sucesso e registre o digest antes de criar a Stack.

Alternativa manual, **somente quando autorizado**:

```sh
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u SEU_USUARIO --password-stdin
docker push ghcr.io/rhuanwarles/chatwoot:v1.0.0
```

Para pull privado, use PAT com permissão de leitura de packages e autorização SSO se aplicável. Nunca commitar tokens. Para publish via Actions não é necessário colocar PAT pessoal no workflow. Referência: [GitHub — publicação de imagens](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images).

## 4. Variáveis e persistência

Copie `.env.example` para `.env` **apenas para uso CLI**, ou carregue seus valores na tela Environment da Stack no Portainer. Substitua todos os `REPLACE_*`. Gere segredos próprios para instalação nova; para migrar a existente, reutilize as chaves originais.

Obrigatórios: `FRONTEND_URL`, `SECRET_KEY_BASE`, três `ACTIVE_RECORD_ENCRYPTION_*`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`. Confira host/porta/database/usuário de PostgreSQL e `REDIS_URL`; mantenha os mesmos valores em Web e worker. `DATABASE_URL` fica vazio por padrão, podendo configurar TLS e parâmetros de banco gerenciado. Não deixar URI antiga apontando para outro banco. Variáveis individuais permanecem exigidas para configuração explícita.

Configurar manualmente conforme uso: SMTP/remetente; OAuth Google; storage S3 e credenciais/região; HTTPS/proxy. Configurações OAuth salvas em Super Admin prevalecem sobre ENV. Guia funcional: [README-DEPLOY](../../README-DEPLOY.md), [Calendar](../../docs/crm/google-calendar.md).

`FORCE_SSL=true` pressupõe proxy HTTPS correto. `WEB_BIND_ADDRESS=127.0.0.1` permite proxy no host. Proxy em container deve compartilhar a rede e apontar para `web:3000`; não usar localhost do proxy. Só alterar o bind para `0.0.0.0` quando houver controle apropriado de firewall/acesso.

Volumes têm nomes explícitos configuráveis: `STORAGE_VOLUME`, `POSTGRES_VOLUME`, `REDIS_VOLUME`. Eles persistem em redeploy; ambientes diferentes no mesmo Docker devem usar nomes diferentes para não compartilhar dados. Na migração da VPS atual, use os volumes reais identificados por `docker inspect`, não os nomes de exemplo. Não iniciar stack nova contra volumes de outra instalação sem mapear banco/keys/upload.

O modo `local` exige backup de storage; S3 exige backup/política do bucket. O volume de PostgreSQL persiste o banco e Redis usa AOF. Não publicar portas PostgreSQL/Redis. A Evolution continua separada: seu banco, sessões, volumes e integração não são recriados por esta release.

## 5. Deploy CLI e migrations, instalação nova

```sh
cd deploy/production
cp .env.example .env
# Edite os segredos antes de continuar.
chmod 600 .env
docker compose --env-file .env -f stack.bundled.yaml config --quiet
docker compose --env-file .env -f stack.bundled.yaml pull
docker compose --env-file .env -f stack.bundled.yaml up -d postgres redis
docker compose --env-file .env -f stack.bundled.yaml run --rm --no-deps web \
  bundle exec rails db:chatwoot_prepare
docker compose --env-file .env -f stack.bundled.yaml up -d web worker
```

Antes de preparar, aguarde PostgreSQL/Redis saudáveis. Execute `db:chatwoot_prepare` **uma vez**, com a imagem da versão e o ENV corretos. O comando específico do projeto carrega schema/seeds na primeira instalação e aplica migrations; em banco existente aplica migrations. Web, worker e healthchecks não executam migrations automaticamente. Nunca rodar preparação simultaneamente em vários containers.

Para banco externo, use `stack.yaml`; providencie previamente banco, extensão pgvector conforme permissões do provedor, Redis e conectividade. `POSTGRES_HOST=postgres` não resolve fora da Stack sem uma rede compartilhada/alias. Para serviços Docker externos, conecte ambos os serviços à network externa correta por uma alteração explícita da Stack; para gerenciados use DNS, TLS e firewall adequados. Teste DNS/autenticação a partir dos containers.

## 6. Portainer: sequência sem build no servidor

1. Se a imagem for privada, cadastre GHCR em **Registries** com credencial de pull.
2. Escolha Docker Standalone, crie Stack com nome estável e cole **um arquivo completo**: `stack.bundled.yaml` ou `stack.yaml`. Ambos usam imagens, não `build`, bind de source nem `env_file`.
3. Preencha Environment; no modo interno mantenha hosts `postgres`/`redis`, no externo ajuste os destinos. Fixe imagem em `:v1.0.0` ou `@sha256:...`.
4. Para instalação nova, a primeira subida Web pode aguardar/falhar até preparar o banco. Pare Web e worker pelo Portainer enquanto prepara. Dependencies/volumes devem permanecer ativos.
5. Em terminal do Docker host, encontre o nome exato do container Web e execute uma única vez a imagem-alvo com a configuração da Stack. Se o Web estiver rodando, pode usar `docker exec CONTAINER_WEB bundle exec rails db:chatwoot_prepare` com worker parado e sem tráfego. A alternativa preferida é usar o mesmo YAML/ENV no host e `docker compose run --rm --no-deps web ...` como acima, mantendo o nome de projeto/Stack, imagem, volumes e redes iguais.
6. Suba/reinicie Web e worker e verifique logs/healthchecks. Configure proxy, TLS e domínio fora desta Stack. Não executar migrations via start automático de todos os serviços.

O healthcheck `/health` verifica resposta HTTP do Rails, não valida migrations, Redis nem prontidão completa do negócio. PostgreSQL e Redis têm probes próprios. A Stack não inventa probe de Sidekiq; confira processo e execução de jobs em operação. Sem Compose v2/Standalone, prepare um manifesto específico, não reutilize estes arquivos diretamente em Swarm.

## 7. Atualizar e fazer rollback

Antes de atualizar: backup testado do banco/storage, chaves preservadas, changelog/migrations revisados e digest anterior registrado. Troque `CHATWOOT_IMAGE` para a versão nova **em ambos os serviços**; faça pull. Programe janela conforme compatibilidade de schema, pare worker e tráfego, prepare o banco uma vez com a imagem-alvo e redeploye Web/worker. Não renomeie volumes/Stack.

No CLI:

```sh
# Após atualizar CHATWOOT_IMAGE no .env e fazer backup:
docker compose --env-file .env -f stack.bundled.yaml pull web worker
docker compose --env-file .env -f stack.bundled.yaml stop web worker
docker compose --env-file .env -f stack.bundled.yaml run --rm --no-deps web bundle exec rails db:chatwoot_prepare
docker compose --env-file .env -f stack.bundled.yaml up -d web worker
```

Rollback: altere a imagem de ambos de `:v1.1.0` para `:v1.0.0` (ou digest anterior), pull e redeploy. **Imagem antiga não desfaz migrations.** Só voltar se o schema for compatível; caso contrário planeje restauração do backup, com impacto nos dados novos. Nenhuma migration é revertida automaticamente. Nunca usar `down -v`, reset ou prune de volumes.

## Validação desta preparação

Revisar sintaxe dos dois Composes com valores fictícios; comparar ENV/imagem de Web/worker; conferir nomes de volumes; validar Dockerfile/workflow e exclusão de segredos. Um YAML válido não comprova um build completo nem acesso ao GHCR. Não anunciar que a imagem existe até o workflow terminar. Docker local indisponível ou falta de recursos deve ser registrada como limitação, sem executar build pesado/redeploy na produção para compensar.
