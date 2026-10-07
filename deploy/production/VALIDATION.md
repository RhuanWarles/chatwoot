# Validação da stack

## Publicação v1.0.10 — 07/10/2026

- Build completo linux/amd64 concluído com sucesso no [GitHub Actions](https://github.com/RhuanWarles/chatwoot/actions/runs/37569479915).
- Imagem: `ghcr.io/rhuanwarles/chatwoot:v1.0.10`.
- Digest do índice: `sha256:48a6c1acfed9847fc21aff1930d20d5f4525388afd7bb2858de48c2aafef0360`.
- Manifesto consultado sem autenticação privada: HTTP 200; plataforma linux/amd64 confirmada.
- Labels conferidos: versão `v1.0.10`, revisão `dce92c12a6d724955d431742874e39a612eea2e3`.
- Tag `v1.0.10` e branch `release/crm-v1.0.10` publicadas no GitHub.
- Não houve deploy, restart, alteração de stack ou de configuração na VPS nesta publicação.
- Inicialização com banco/storage novos e homologação funcional dessa imagem continuam pendentes.

## Preparação v1.0.10 — 07/10/2026

- Código de aplicação: `9732da7e52`, já em execução na VPS por rebuild direto.
- `stack.bundled.yaml` inclui PostgreSQL/pgvector, Redis, prepare, Web e worker.
  `stack.yaml` usa PostgreSQL/Redis externos. Ambos apontam para v1.0.10.
- Acrescentadas apenas as variáveis de runtime `EVOLUTION_API_URL`,
  `EVOLUTION_API_KEY` e `EVOLUTION_INSTANCE_NAME`, compartilhadas por prepare,
  Web e worker. Nenhuma credencial real é incluída.
- Dependência do patch externo da Evolution 2.3.7 documentada explicitamente.
- Os dois YAMLs passaram em `docker compose config`; imagem e variáveis
  compartilhadas, gate de prepare e ausência de portas publicadas para os bancos
  foram conferidos com os valores fictícios de `.env.example`, sem subir serviços.
- Testes da renderização: 23 aprovados, lint aprovado e componentes Vue compilados.
- Rebuild direto da VPS validado com HTTP 200 local/público e assets HTTP 200;
  Rails/Sidekiq no código atual e instâncias Evolution conectadas.
- A publicação e o digest foram confirmados posteriormente, conforme registro acima.
  O teste de instalação nova dessa release permanece pendente.
- A preparação desta stack não faz redeploy na VPS.

## Validação original v1.0.0 — 04/10/2026

## Verificado

- `docker build --check`: exit 0, sem avisos. Não executa o build completo.
- `docker compose config --quiet` para `stack.yaml` e `stack.bundled.yaml`: exit 0, com valores fictícios.
- Configuração resolvida: Web e worker usam a mesma imagem e o mesmo ENV relevante; apenas Web tem PIDFILE específico.
- Volumes nomeados e persistentes; PostgreSQL/Redis não têm portas publicadas.
- Nenhum serviço inicia migrations; preparação usa `db:chatwoot_prepare` separado.
- Stacks sem build, `env_file` ou bind de código da VPS; suporte documentado a Docker Standalone.
- actionlint v1.7.12: workflow GHCR e dois workflows herdados validados, exit 0. Integração shellcheck/pyflakes não executada.
- `.env`/`.env.local` de deployment ignorados pelo Git; `.env.example` disponível para versionar.
- Contexto Docker exclui `.git`, `.codex`, worktrees, `.env`, dumps e assets Vite antigos.
- `git diff --check` sem erros.
- Mensagem PT-BR `PIPELINE_NO_STAGES` corrigida para “Este pipeline não possui etapas disponíveis.”, sem alteração de lógica.

## Snapshot de produção preservado

Estes arquivos foram copiados da VPS para o PC sem novos ajustes de lógica nesta etapa:

- `app/javascript/dashboard/routes/dashboard/crm/pages/CrmDealDetails.vue`
- `app/javascript/dashboard/routes/dashboard/crm/pages/CrmDeals.vue`
- `app/models/crm/deal.rb`
- `app/models/crm/deal_event.rb`
- `app/javascript/dashboard/i18n/locale/en/crm.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/crm.json`
- `app/javascript/dashboard/i18n/locale/en/en.json`

Isso incorpora à futura release os ajustes que já rodavam na produção, mas não estavam no GitHub. Depois da comparação byte a byte, somente o texto de `PIPELINE_NO_STAGES` foi corrigido no arquivo PT-BR. Não houve redeploy, migration ou alteração de banco na preparação.

## Pendências antes de anunciar estabilidade/publicar

- Build completo da imagem e inicialização com banco/Redis/storage isolados. Docker Desktop local estava indisponível; a VPS não foi usada para um build pesado por estar com pouco disco livre.
- Homologação da imagem final: login, jobs, anexos, CRM, migrations e integrações configuradas. Os testes funcionais anteriores do CRM não substituem este teste da imagem construída do zero.
- Revisar secrets/permissões do GitHub Packages, criar commit/tag e autorizar push/publicação.
- Confirmar pull pelo Portainer e registrar digest. A imagem `ghcr.io/rhuanwarles/chatwoot:v1.0.0` ainda não existe como resultado desta preparação.

Não foram criados commit ou tag de release, feitos push, publicação no GHCR, atualização da Stack de produção ou rollback.

## Publicação posterior — v1.0.4, 04/10/2026

- Publicação autorizada pelo usuário e concluída via GitHub Actions: https://github.com/RhuanWarles/chatwoot/actions/runs/37186559952.
- Build completo linux/amd64 concluído com sucesso a partir de `518b1f6cdfda5ebbc18e158e8581f41fce355839`.
- Imagem: `ghcr.io/rhuanwarles/chatwoot:v1.0.4`.
- Digest: `sha256:7e0a5429021a9f66fa62eec5ac84d0090d931bd17bda877b6b9ee0cc555609fa`.
- Consulta anônima do manifesto: HTTP 200, confirmando acesso público para pull.
- A tag v1.0.0 era herdada do upstream e não continha o workflow do CRM; foi preservada. v1.0.4 identifica a imagem do código atual.
- Stacks e exemplo de ENV atualizados para v1.0.4. Código e documentação enviados à branch feat/saas-ai-usage.
- Não houve execução local do projeto nem redeploy/migrations na VPS.
- Inicialização e homologação funcional da imagem em ambiente isolado continuam pendentes; sucesso do build não comprova funcionamento das integrações.

## Auditoria posterior — 04/10/2026

Relatório completo em [AUDITORIA.md](AUDITORIA.md).

- Encontrado bloqueio de partida: ambos os YAMLs injetavam `DATABASE_URL` vazia; Active Record 7.2.3.1 lança `Database URL cannot be empty`. Reprodução isolada confirmou erro; ausência da variável usa os campos POSTGRES normalmente.
- Removida DATABASE_URL das Stacks e do exemplo ENV; guia documenta URI não vazia como configuração explícita para banco externo. Correção local ainda não enviada ao GitHub nesta auditoria.
- Camada /app da imagem pública inspecionada diretamente: digest validado; 197 migrations iguais ao repositório, oito do CRM; scripts executáveis; modelos/páginas CRM iguais ao código auditado.
- Manifest Vite presente, 74 arquivos JS/CSS e nenhum asset referenciado ausente.
- Ambos os YAMLs corrigidos passam em docker compose config; omissão de FRONTEND_URL impede interpolação.
- Teste isolado ActionDispatch::SSL 7.2.3.1 confirmou HTTP 301 sem header e 200 com X-Forwarded-Proto=https.
- pg_isready executado somente em leitura no PostgreSQL local existente. Probe autenticada Redis validada num container temporário com a imagem local disponível.
- Não houve pull completo da imagem, subida integral, migrations reais, push ou alteração de produção. Docker ainda armazena dados no C:, com aproximadamente 490 MB livres. Testes de mecanismos usaram imagens locais existentes, sem substituir a homologação da v1.0.4 publicada.

## Preparação automática da Stack — 04/10/2026

- Serviço prepare adicionado às duas Stacks, com mesma imagem/ENV/storage e restart no.
- Bundled: PostgreSQL/Redis healthy antes de prepare; prepare exit 0 antes de Web/worker.
- App-only: dependência em prepare, sem inventar banco/Redis internos; dependências externas devem estar disponíveis previamente.
- EntryPoint vazio em prepare: executa somente o task Rails, sem setup/bundle install do entrypoint Web.
- docker compose config --format json passou para ambos com valores fictícios em Compose v5.3.0; imagem compartilhada e completion gate verificados. git diff --check passou.
- Não houve partida local do projeto, migrations reais, teste de falha/redeploy em runtime, push ou deploy remoto. Respeitada a instrução de não executar o projeto na máquina do usuário.
- Compatibilidade na versão específica do Portainer-alvo permanece pendente. Uma mudança para nova tag recria prepare; dependências não param containers antigos durante update, nem serializam stacks concorrentes. Procedimento de parada pelo Portainer documentado.
