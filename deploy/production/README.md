# Release CRM v1.1.0: GHCR e Portainer

Veja a [auditoria técnica](AUDITORIA.md) antes do primeiro deploy: inclui correção de `DATABASE_URL` vazia, geração de chaves, variáveis exatas, comandos de preparação/update e limites dos testes realizados.

Este pacote reutiliza `docker/Dockerfile`. A mesma imagem executa Web e Sidekiq. Os arquivos abaixo destinam-se a **Portainer com Docker Standalone / Compose v2**, não a Docker Swarm. O código da VPS foi incorporado como snapshot sem novas regras de produto. A instalação existente não foi redeployada.

## Arquivos e requisitos

- `stack.bundled.yaml`: instalação nova com PostgreSQL 16/pgvector, Redis 7, Web e worker.
- `stack.yaml`: Web e worker para PostgreSQL/Redis já disponíveis.
- `.env.example`: variáveis de exemplo; no Portainer são variáveis da Stack, sem dependência de arquivo `.env` no host.
- `../../docker/Dockerfile`: Ruby 3.4.4, Node 24, pnpm 10.2.0, gems e assets compilados.
- `../../.github/workflows/crm-image.yml`: build linux/amd64; publicação exclusivamente ao enviar tag `vX.Y.Z`.

Imagem da release: **`ghcr.io/rhuanwarles/chatwoot:v1.1.0`** (linux/amd64).
Publicação e digest: consulte [VALIDATION.md](VALIDATION.md).
Inicialização e homologação em instalação nova permanecem pendentes.
Não usar a imagem oficial pura ou `latest` como referência de release. Para ARM,
preparar/testar build adicional antes de usar; o workflow publica apenas amd64.

Esta versão consolida o estado atual: CRM, navegação horizontal do Kanban, AI Agents, envio de áudio/texto, menções e gestão de grupos WhatsApp. A seção de grupos reúne informações, modal de nome/foto, participantes compactos e zona de perigo.
Gerar/publicar esta stack não substitui a instalação existente da VPS.

`v1.1.0` versiona este CRM/fork, não substitui a versão upstream registrada em `VERSION_CW`/`package.json`.

## 1. Revisão antes da tag

Confira `git status`, `git diff` e o [changelog](../../CHANGELOG.md). As mudanças de produto já em execução na VPS precisam entrar no commit junto ao empacotamento; não descarte arquivos não commitados. Nenhuma credencial da VPS deve entrar na árvore Git ou no contexto de build.

O Dockerfile escreve `.git_sha` a partir de `SOURCE_REVISION`, aceita `CRM_VERSION` e não precisa copiar `.git` para a imagem. Normaliza scripts recebidos com CRLF. O build é feito do código completo; não usa uma camada improvisada sobre a imagem de produção da VPS.

Antes de publicar, faça build completo e teste login, Kanban, Deal, campos inline, Activities, histórico e integração configurada num ambiente separado. O rótulo v1.1.0 não substitui homologação. As bases Docker e repositórios de pacotes usam tags: a mesma tag de source não garante bytes idênticos em rebuilds futuros. Depois de publicar, registre o digest e use-o para pinning quando precisar de identidade exata.

## 2. Build local sem publicar

Linux/WSL com Docker disponível, na raiz do projeto:

```sh
REVISION=$(git rev-parse HEAD)
docker build --check -f docker/Dockerfile .
docker build -f docker/Dockerfile \
  --build-arg SOURCE_REVISION="$REVISION" \
  --build-arg CRM_VERSION=v1.1.0 \
  -t ghcr.io/rhuanwarles/chatwoot:v1.1.0 .
```

Não fazer build pesado na VPS com pouco disco/RAM. O build usa lockfiles, mas precisa acessar os repositórios Ruby/Node/Alpine. Não passe segredos de produção como build args. Instalações reais recebem ENV somente em runtime.

## 3. Criar commit/tag e publicar — executar somente após aprovação

O preparo não executa os comandos abaixo. Na branch desejada:

```sh
git status --short
git diff --check
# Revise todos os arquivos; não inclua .env real, dumps ou chaves.
git add .
git commit -m "release: CRM v1.1.0"
git tag -a v1.1.0 -m "CRM v1.1.0"
git push origin release/crm-v1.1.0
git push origin v1.1.0
```

Verifique se `v1.1.0` já existe antes de criá-la. Não mover tags de release publicadas. O workflow usa `GITHUB_TOKEN`, `contents: read` e `packages: write`, publica `v1.1.0` e `sha-<commit-completo>`, preserva o código do fork e não chama Portainer. Os workflows herdados de publicação DockerHub foram limitados ao upstream `chatwoot/chatwoot`, evitando publicação paralela errada neste fork.

No GitHub, habilite Actions e confira permissão de escrita em Packages. Para repositórios/organizações com restrições, conceda acesso do workflow ao pacote. A visibilidade inicial do pacote pode exigir ajuste no GHCR. Aguarde sucesso e registre o digest antes de criar a Stack.

Alternativa manual, **somente quando autorizado**:

```sh
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u SEU_USUARIO --password-stdin
docker push ghcr.io/rhuanwarles/chatwoot:v1.1.0
```

Para pull privado, use PAT com permissão de leitura de packages e autorização SSO se aplicável. Nunca commitar tokens. Para publish via Actions não é necessário colocar PAT pessoal no workflow. Referência: [GitHub — publicação de imagens](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images).

## 4. Variáveis e persistência

Copie `.env.example` para `.env` **apenas para uso CLI**, ou carregue seus valores na tela Environment da Stack no Portainer. Substitua todos os `REPLACE_*`. Gere segredos próprios para instalação nova; para migrar a existente, reutilize as chaves originais.

Obrigatórios: `FRONTEND_URL`, `SECRET_KEY_BASE`, três `ACTIVE_RECORD_ENCRYPTION_*`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`. Confira host/porta/database/usuário de PostgreSQL e `REDIS_URL`; mantenha os mesmos valores em Web e worker. As Stacks não definem `DATABASE_URL`: no Rails 7.2, uma string vazia causa `Database URL cannot be empty`. Para banco gerenciado que exija URI/TLS, adicione explicitamente uma `DATABASE_URL` não vazia ao bloco `environment: &app-env` do `stack.yaml`, por exemplo `DATABASE_URL: ${DATABASE_URL:?Set a non-empty DATABASE_URL}`. A URI prevalece sobre os campos individuais; codifique caracteres especiais de usuário/senha na URL. Somente cadastrar a variável na tela do Portainer não a injeta em um YAML que não a referencia.

Configurar manualmente conforme uso: SMTP/remetente; OAuth Google; storage S3 e credenciais/região; HTTPS/proxy. Configurações OAuth salvas em Super Admin prevalecem sobre ENV. Guia funcional: [README-DEPLOY](../../README-DEPLOY.md), [Calendar](../../docs/crm/google-calendar.md).

Para participantes/menções de grupos, preencher `EVOLUTION_API_URL` com a URL
acessível a Web/worker e `EVOLUTION_API_KEY` com a chave da Evolution. Elas são
variáveis de runtime do backend; não colocar a chave nos atributos da Inbox.
Em Configurações → Caixas de Entrada → Inbox API → Configuração, informar o nome
da instância Evolution. `EVOLUTION_INSTANCE_NAME` é apenas o fallback de instalação.
Não confundir o nome da instância com seu UUID.

A Evolution continua externa a esta stack. O envio real de menções exige o
[patch do adaptador Evolution 2.3.7](../evolution/README.md); configurar URL/chave
ou atualizar só o Chatwoot não aplica esse patch. A stack não cria instâncias,
não gerencia sessões e não altera o banco ou a implantação da Evolution.

`FORCE_SSL=true` pressupõe proxy HTTPS correto. `WEB_BIND_ADDRESS=127.0.0.1` permite proxy no host. Proxy em container deve compartilhar a rede e apontar para `web:3000`; não usar localhost do proxy. Só alterar o bind para `0.0.0.0` quando houver controle apropriado de firewall/acesso.

Volumes têm nomes explícitos configuráveis: `STORAGE_VOLUME`, `POSTGRES_VOLUME`, `REDIS_VOLUME`. Eles persistem em redeploy; ambientes diferentes no mesmo Docker devem usar nomes diferentes para não compartilhar dados. Na migração da VPS atual, use os volumes reais identificados por `docker inspect`, não os nomes de exemplo. Não iniciar stack nova contra volumes de outra instalação sem mapear banco/keys/upload.

O modo `local` exige backup de storage; S3 exige backup/política do bucket. O volume de PostgreSQL persiste o banco e Redis usa AOF. Não publicar portas PostgreSQL/Redis. A Evolution continua separada: seu banco, sessões, volumes e integração não são recriados por esta release.

## 5. Deploy automático e atualização

A stack bundled executa automaticamente: PostgreSQL/Redis healthy → prepare → Web/worker. `prepare` usa a mesma imagem, ENV e storage, `restart: 'no'`, `entrypoint: []` e apenas `bundle exec rails db:chatwoot_prepare`. O entrypoint da imagem não é necessário: as gems estão incluídas e a dependência garante PostgreSQL disponível. Web/worker mantêm seus comandos/entrypoint atuais e não executam migrations.

No Portainer Docker Standalone: Add stack → Web editor → colar YAML → preencher Environment → Deploy the stack → aguardar. Não há comando manual de preparação. Configure domínio/proxy/TLS previamente. `prepare` em **Exited (0)** significa sucesso. Se falhar, seus logs contêm o erro e novos Web/worker não iniciam. Corrija a causa e redeploye pelo Portainer; não ignore o erro.

Na app-only, provisionar PostgreSQL e Redis externos disponíveis antes do Deploy, com DNS, autenticação e rede corretos. Não há serviços locais nem healthchecks externos: a preparação falha se não conseguir acessar PostgreSQL. A saúde de Redis externo deve ser garantida pelo operador; o task não é uma probe completa de Redis.

Para atualizar: faça backup, suspenda tráfego e pare **Web e worker pelo Portainer**, mantendo banco/Redis. Troque `CHATWOOT_IMAGE` para uma nova tag publicada em Environment e clique Update the stack, solicitando pull da imagem. A mudança da imagem compartilhada recria `prepare`, que executa novamente antes da partida da aplicação. Preserve Stack, volumes e chaves. Uma atualização da mesma tag não comprova troca de imagem; use tags novas.

**Limitação:** `depends_on` controla a partida via Compose; não interrompe containers antigos já em execução durante migrations nem controla reinícios isolados do Docker. Por isso a parada de Web/worker pelo Portainer é necessária em atualizações, especialmente migrations incompatíveis. Não existem migrations no entrypoint para contornar essa limitação. Uma única Stack deve gerenciar o banco; stacks concorrentes não são serializadas por esse YAML.

Compose moderno suporta `service_completed_successfully`: https://docs.docker.com/compose/how-tos/startup-order/. O Portainer oferece Web editor/Environment para Docker Standalone: https://docs.portainer.io/user/docker/stacks/add. A versão específica do Portainer-alvo não foi testada; se rejeitar a condição, atualize para uma versão com suporte antes de usar. Não utilizar no Swarm.

Rollback: voltar a imagem não desfaz migrations. Só use uma imagem anterior compatível com o schema; caso contrário, planeje restauração de backup. Nunca remover volumes para atualizar ou reverter.

## Validação desta preparação

Revisar sintaxe dos dois Composes com valores fictícios; comparar ENV/imagem de Web/worker; conferir nomes de volumes; validar Dockerfile/workflow e exclusão de segredos. Um YAML válido não comprova um build completo nem acesso ao GHCR. Não anunciar que a imagem existe até o workflow terminar. Docker local indisponível ou falta de recursos deve ser registrada como limitação, sem executar build pesado/redeploy na produção para compensar.
