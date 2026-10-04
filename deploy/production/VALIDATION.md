# Validação da preparação v1.0.0 — 04/10/2026

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