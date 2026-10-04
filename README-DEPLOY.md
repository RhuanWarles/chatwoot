# Instalação do Chatwoot com CRM e Evolution API

Guia deste fork, incluindo Deals, Pipelines, Custom Fields, Activities e integração Google Calendar/Meet. Os exemplos não contêm credenciais da VPS.

## 1. Escolha do ambiente

O caminho reproduzível é Docker Compose com containers Linux: VPS Linux, computador Linux, macOS com Docker Desktop ou Windows com Docker Desktop/WSL2. No Windows, execute os comandos deste guia no terminal Ubuntu do WSL2; eles usam Bash, não PowerShell. Guarde o checkout no filesystem Linux do WSL2 para evitar problemas de desempenho e permissões.

Em Kubernetes ou serviços gerenciados, mantenha os mesmos componentes e variáveis, adaptando volumes, DNS, secrets, jobs de migração e ingress. O Compose abaixo não é um manifesto Kubernetes nem uma garantia para qualquer plataforma.

Você precisa de Git, Docker Engine/Desktop e Compose v2 (`docker compose version`). Como ponto de partida para uma instalação pequena, reserve 4 vCPU, 8 GB de RAM e pelo menos 30 GB livres; build, anexos, banco e tráfego podem exigir mais. Compile a imagem em uma máquina maior/CI se a VPS tiver pouca memória ou disco. Verifique a disponibilidade da imagem Evolution escolhida para a arquitetura do servidor; o ambiente de referência usa Linux x86_64.

Componentes necessários:

| Componente | Função | Porta interna |
|---|---|---|
| Rails | Interface e API do Chatwoot | 3000 |
| Sidekiq | Filas, webhooks e sincronizações | sem porta web |
| PostgreSQL com pgvector | Banco do Chatwoot/CRM | 5432 |
| Redis Chatwoot | Filas e cache | 6379 |
| Evolution, opcional | WhatsApp e ponte com Chatwoot | 8080 |
| PostgreSQL/Redis Evolution | Persistência própria da Evolution | 5432/6379 |

O fork deve ser compilado a partir deste repositório: a imagem oficial genérica do Chatwoot não inclui estas alterações de CRM. A referência inspecionada usa Ruby 3.4.4, Node 24, pnpm 10.2.0, PostgreSQL 16 com pgvector, Redis 7 e Evolution 2.3.7. As versões do Dockerfile e lockfiles do commit escolhido são a fonte de verdade; 2.3.7 é a versão usada nesta instalação, não uma indicação de versão mais recente.

## 2. Código e segredos — instalação NOVA

```bash
git clone https://github.com/RhuanWarles/chatwoot.git
cd chatwoot
# Selecione a branch/tag/commit que realmente contém as mudanças do CRM.
# Confira: app/models/crm e app/javascript/dashboard/routes/dashboard/crm.
cd deploy/portable
cp .env.example .env
chmod 600 .env
```

Não use esse Compose diretamente para substituir uma instalação existente: veja a seção de migração. Ele cria volumes sob um novo nome de projeto.

Preencha `.env` antes de iniciar. Para cada segredo, gere um valor diferente:

```bash
openssl rand -hex 32
```

Use a saída para `SECRET_KEY_BASE`, as três chaves `ACTIVE_RECORD_ENCRYPTION_*`, senhas PostgreSQL/Redis e `EVOLUTION_API_KEY`. Senhas hexadecimais evitam caracteres especiais nas URIs do exemplo. Se reutilizar senhas com `@`, `:`, `/`, `%` etc., codifique usuário/senha como componentes de URI; não cole uma senha sem escape em `DATABASE_CONNECTION_URI`.

Preserve as chaves de criptografia durante upgrades/restauração: sem elas, credenciais Google existentes não podem ser descriptografadas. Não publique `.env`, dumps, tokens ou chaves SSH no Git. O arquivo `.env.example` contém apenas placeholders e não funciona sem preenchimento.

Para uso local, mantenha `FRONTEND_URL=http://localhost:3000`. Em produção, use a URL HTTPS pública real. Defina `EVOLUTION_SERVER_URL` com a URL acessível pelo Rails/Sidekiq: o exemplo local usa `http://evolution:8080`; em produção pode usar `https://evolution.seudominio.com.br`.

## 3. Compilar e iniciar o Chatwoot

Execute dentro de `deploy/portable`:

```bash
docker compose --env-file .env config --quiet
docker compose build rails
docker compose up -d postgres redis
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d rails sidekiq
docker compose ps
docker compose logs --tail=100 rails sidekiq
curl -I http://127.0.0.1:3000
```

`db:chatwoot_prepare` prepara/migra o banco usando o código do fork, incluindo as migrations CRM. Não rode `db:reset` ou seeds de desenvolvimento em produção. Rails e Sidekiq devem usar a mesma imagem, banco, Redis e chaves de criptografia.

Abra `http://localhost:3000`, conclua o cadastro inicial e crie a account. Depois altere `ENABLE_ACCOUNT_SIGNUP=false` se não desejar cadastro público e aplique com `docker compose up -d --no-deps rails sidekiq`. Para administrar a instalação, utilize um usuário Super Admin provisionado pelo fluxo nativo; ser administrador de uma account não concede automaticamente acesso ao Super Admin.

As portas são vinculadas a `127.0.0.1`. Para acessar uma VPS antes de configurar domínio:

```bash
ssh -L 3000:127.0.0.1:3000 -L 8085:127.0.0.1:8085 usuario@servidor
```

Abra os endereços locais no navegador enquanto o túnel estiver ativo. Não exponha PostgreSQL/Redis na internet.

## 4. Domínio, HTTPS e proxy

Configure DNS, certificado válido e proxy reverso para Rails e, se necessário, Evolution. Nginx instalado no host pode usar `127.0.0.1:3000` e `127.0.0.1:8085`; Nginx em container precisa compartilhar a rede e usar `chatwoot:3000` / `evolution:8080`, pois seu `localhost` é outro container.

Trecho de referência dentro de um servidor Nginx com TLS já configurado:

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
location /cable {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

Ajuste limites de upload ao tamanho dos anexos esperado. Atualize `FRONTEND_URL` e `EVOLUTION_SERVER_URL` quando mudar de domínio. Cloudflare não deve bloquear webhooks, APIs ou WebSocket com desafios de navegador. HTTPS público é necessário para OAuth Google fora do cenário local permitido pelo provedor.

## 5. E-mail e armazenamento

Preencha as variáveis `SMTP_*` e `MAILER_SENDER_EMAIL` com os dados reais do provedor. O exemplo usa SMTP na porta 587 com STARTTLS; adapte ao provedor, sem misturar SSL direto e STARTTLS. Configure SPF/DKIM/DMARC e teste convites e recuperação de senha. SMTP configura os e-mails enviados pelo sistema; receber e-mails de clientes exige também uma inbox de e-mail configurada no Chatwoot.

O exemplo usa `ACTIVE_STORAGE_SERVICE=local` e volume `storage_data`. Inclua esse volume no backup. Para S3 compatível, use as variáveis existentes em `.env.example` da raiz e configure o serviço correspondente; mantenha arquivos acessíveis ao Rails e Sidekiq.

## 6. Evolution API — instalação NOVA

Preencha as quatro variáveis `EVOLUTION_*` de URL/chaves/senhas e execute:

```bash
docker compose --profile evolution up -d evolution-postgres evolution-redis evolution
docker compose --profile evolution logs --tail=100 evolution
```

O Manager da versão utilizada pode ser acessado em `http://localhost:8085/manager`; a autenticação usa `EVOLUTION_API_KEY`. Não exponha a chave em URLs, prints ou logs compartilhados. Crie uma instância pelo Manager/API e conecte o WhatsApp pelo QR code. Para importação inicial de histórico, confira o fluxo suportado pela versão; não desconecte/recrie sessões existentes apenas para reimportar.

### Três endereços diferentes

| Configuração | Destino correto |
|---|---|
| URL Chatwoot na integração da instância | `http://chatwoot:3000` neste Compose, ou domínio HTTPS público |
| `SERVER_URL` da Evolution | Endereço que Rails/Sidekiq usam para chamar a Evolution |
| `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` | PostgreSQL do **Chatwoot**, nunca o banco principal da Evolution |

O Compose configura:

```text
DATABASE_CONNECTION_URI=postgresql://evolution:[SENHA_EVOLUTION]@evolution-postgres:5432/evolution
CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=postgresql://postgres:[SENHA_CHATWOOT]@chatwoot-db:5432/chatwoot?sslmode=disable
```

Os bancos são distintos. O acesso direto ao banco Chatwoot é usado pelo mecanismo de importação/vínculo de mensagens da Evolution desta versão. `sslmode=disable` é para PostgreSQL interno deste exemplo; banco externo com TLS deve usar o modo exigido pelo provedor. Nunca deixe placeholders como `host`, `user`, `password` na URI funcional.

### Configurar a instância para Chatwoot

No Chatwoot, obtenha o token API do perfil do usuário da account desejada. Na Evolution, habilite Chatwoot para a instância e configure:

- URL Chatwoot sem `/app` e sem acrescentar `/api/v1`;
- Account ID real, disponível na URL do Chatwoot;
- token do usuário dessa account;
- nome da inbox, por exemplo `rwhub`;
- `conversationPending=false` para novas conversas abertas;
- `reopenConversation` conforme a regra desejada para conversas resolvidas;
- importação de contatos/mensagens conforme necessidade, avaliando o volume.

Confirme a criação da inbox API e seu webhook. A URL deve apontar para a Evolution e a instância correta, no formato `SERVER_URL/chatwoot/webhook/NOME_DA_INSTANCIA`. Adicione os agentes à inbox no Chatwoot. O token API precisa das permissões necessárias; não use uma conta de outro tenant.

Mensagens enviadas pelo Chatwoot passam por Sidekiq → webhook Evolution → WhatsApp. Mensagens recebidas fazem WhatsApp → Evolution → API Chatwoot. Portanto, valide conectividade nos dois sentidos.

### Validar comunicação interna

```bash
docker compose exec evolution node -e "require('dns').lookup('chatwoot-db',(e,a)=>{if(e)throw e;console.log(a)})"
docker compose exec evolution node -e "const s=require('net').connect(5432,'chatwoot-db',()=>{console.log('TCP OK');s.end()});s.on('error',e=>{console.error(e.code);process.exit(1)})"
docker compose exec evolution node -e "fetch('http://chatwoot:3000').then(r=>console.log('HTTP',r.status)).catch(e=>{console.error(e.message);process.exit(1)})"
```

DNS/TCP não comprovam senha correta; valide também a conexão PostgreSQL autenticada e um envio real. Um HTTP de redirecionamento pode ser normal, mas redirecionamento para HTTPS precisa ter destino acessível. Se a instalação força HTTPS, use o domínio público ou uma rota interna corretamente configurada; não desative HTTPS globalmente apenas para contornar isso.

## 7. Integração em stacks existentes / Portainer

Antes de alterar, registre imagem, project name, networks, volumes, banco principal e quantidade/estado das instâncias. Leia `docker inspect`, sem compartilhar sua saída completa: `.Config.Env` pode conter senhas.

Na instalação de referência, os containers eram `evolution-api`, `chatwoot-saas-ai-rails-1` e `chatwoot-saas-ai-postgres-1`. São nomes específicos dessa VPS, não exigências para uma instalação nova. A correção da URI foi:

```text
postgresql://postgres:[SENHA_REAL_CHATWOOT]@chatwoot-saas-ai-postgres-1:5432/chatwoot?sslmode=disable
```

Evolution e PostgreSQL Chatwoot devem compartilhar uma rede. Para acesso imediato, se ainda não estiverem conectados:

```bash
docker network connect chatwoot-saas-ai_default evolution-api
```

Isso não desconecta outras redes. Persista também a associação no Compose/stack original, preservando as redes anteriores. Exemplo de rede externa na stack Evolution:

```yaml
services:
  evolution-api:
    networks: [default, chatwoot_database]
networks:
  chatwoot_database:
    external: true
    name: chatwoot-saas-ai_default
```

Se houver outras redes existentes, mantenha-as na lista. Prefira aliases exclusivos; `postgres` pode colidir quando diferentes stacks compartilham uma rede.

No Portainer, edite a stack original e salve somente a variável necessária, mantendo volumes, imagem, banco e demais ENV. `docker restart` não recarrega ENV alterado no Compose: é necessário redeploy/recriação segura do serviço. Antes/depois, confira todas as instâncias e `rwhub` conectada. Não troque `COMPOSE_PROJECT_NAME` em uma instalação existente: isso pode selecionar outros volumes e aparentar perda de dados.

Não execute `down -v`, `volume rm`, `db:reset`, prune de volumes ou recriação de sessão para corrigir uma URI/rede.

## 8. Google Calendar e Meet, opcional

No Google Cloud, habilite Calendar API, configure consentimento e crie cliente OAuth **Web**. Cadastre `https://SEU_DOMINIO/crm/google_calendar/callback` como redirect URI exata. Se o app estiver em testes, adicione os usuários de teste; caso contrário podem receber `403 access_denied`.

No Super Admin, configure `GOOGLE_OAUTH_CLIENT_ID` e `GOOGLE_OAUTH_CLIENT_SECRET`. Essas configurações de instalação têm precedência sobre ENV. Não use JSON de service account nem habilite login Google só para conectar Calendar. Se compartilhar o cliente OAuth com login/e-mail, mantenha também os callbacks específicos desses recursos.

Cada usuário conecta sua conta em Configurações → Integrações → Google Calendar. Preserve as três chaves de criptografia. Nas Activities de Reunião, marque a criação no Google Calendar e, se desejado, Meet. O status sincronizado e o link do evento confirmam a criação; convite enviado não significa participação aceita. Sidekiq precisa estar funcionando. Consulte [o guia específico](docs/crm/google-calendar.md).

## 9. Diagnóstico rápido

| Sintoma | Verificação / ação |
|---|---|
| `getaddrinfo EAI_AGAIN host` | URI contém literalmente `host`; substitua pelo DNS real do PostgreSQL Chatwoot e valide rede, porta, senha e banco. |
| Mensagem entregue, mas marcada failed | Compare HTTP/timeout do webhook, logs Evolution/Sidekiq e vínculo `source_id`; a URI incorreta já causou atraso nessa instalação. Não presuma que todo failed tem essa causa. |
| Conversa existe pelo contato, mas não na lista | Compare `status`, `assignee_id`, account/inbox e filtros da tela. “Minhas” exige atribuição; “Abertas” exclui `pending`. |
| `conversationPending=false`, conversa antiga pending | A configuração não deve ser tratada como migração retroativa. Após aprovação, use transição nativa para abrir a conversa existente. |
| Inbox vazia para um agente | Confirme membros/permissões, account correta e “Todos”/“Não atribuídas”. |
| Webhook não dispara | Confira Sidekiq, URL callback, proxy, DNS e acesso Rails → Evolution. |
| Alteração de ENV não apareceu | Redeploy o serviço na stack original; restart simples não troca ENV do container. |
| Alteração de frontend não apareceu | Compile assets, publique a imagem correta, confira manifest servido e recarregue o navegador. Editar `.vue` no host não altera imagem em execução. |
| Activities/Calendar não carregam | Confira migrations, account_id, API Rails, fila e credenciais OAuth; não resete o banco. |
| Disco cheio durante build | Confira `df -h`, `docker system df`; compile em CI. Limpeza de imagens não usadas não substitui gestão de backups/anexos. |

Para comparar listagem e acesso direto, use seu token de forma segura e consulte `GET /api/v1/accounts/ACCOUNT_ID/conversations/DISPLAY_ID` e `GET /api/v1/accounts/ACCOUNT_ID/conversations?inbox_id=INBOX_ID&status=open&assignee_type=all`. O ID na URL é `display_id`, diferente do ID interno do banco. Não troque status ou associações por SQL para esconder um problema de filtro.

## 10. Backup, restauração e migração de máquina

Backup mínimo: código/commit implantado, `.env` e chaves de criptografia, Compose/stack, banco Chatwoot, anexos, banco Evolution, volume de instâncias Evolution e Redis quando necessário. Guarde cópias fora da VPS, com acesso restrito. Faça backup coerente com as aplicações pausadas/sem novas gravações; backup isolado de um volume não garante consistência de toda a integração.

Exemplos para o Compose portátil, executados na pasta dele:

```bash
mkdir -p backups
chmod 700 backups
docker compose exec -T postgres pg_dump -U postgres -d chatwoot -Fc > backups/chatwoot.dump
docker compose --profile evolution exec -T evolution-postgres pg_dump -U evolution -d evolution -Fc > backups/evolution.dump
```

Para volumes de anexos/sessões, use snapshot/backup do volume ou archive com as aplicações pausadas. Descubra os nomes com `docker volume ls`/`docker inspect`; não assuma nomes de outra instalação. Não copie diretamente arquivos de um PostgreSQL rodando como substituto de `pg_dump`/backup físico consistente.

Na máquina nova: instale Docker, recupere o **mesmo commit**, imagem e segredos; crie os serviços de banco; restaure os dumps em bancos novos vazios com `pg_restore`; restaure anexos/sessões nos volumes corretos; prepare/migre o Chatwoot e só então inicie Rails/Sidekiq/Evolution. Se usar outro project name, mapeie explicitamente os volumes restaurados. Não execute fluxo de cadastro/QR como se fosse uma instalação nova antes de conferir a restauração. A sessão WhatsApp restaurada ainda pode precisar de reconexão se o provedor a tiver invalidado; não há garantia de validade externa permanente.

Teste a restauração antes de trocar DNS. Valide contagem de accounts/Deals/instâncias, anexos, login, WhatsApp e Calendar. Mantenha a origem disponível para rollback até confirmar o resultado.

## 11. Atualizar com segurança

Com backup pronto e commit escolhido, compile uma nova tag de imagem. Em janela de manutenção, pause gravações, execute migrations com a nova imagem e suba Rails/Sidekiq na mesma versão. Recrie Evolution somente se sua imagem/ENV precisarem mudar. Não use tag flutuante `latest` para uma atualização não testada.

```bash
# No Compose portátil; ajuste CHATWOOT_IMAGE no .env para uma nova tag.
docker compose build rails
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d --no-deps rails sidekiq
docker compose logs --tail=100 rails sidekiq
```

Rollback de imagem não desfaz migrations; avalie compatibilidade do schema e necessidade de restaurar backup. Preserve a imagem anterior até validar a publicação. Remova apenas imagens comprovadamente não usadas por containers quando decidir dispensar rollback; não limpe volumes.

## 12. Desenvolvimento e validação final

Para desenvolvimento nativo em Linux/WSL2, siga [AGENTS.md](AGENTS.md): Ruby da `.ruby-version`, `rbenv`, `bundle install`, `pnpm install`, PostgreSQL/Redis e `pnpm dev`/Overmind. Use ambiente de desenvolvimento separado, nunca banco de produção. O Compose deste guia executa produção; ele não fornece hot reload.

Antes de considerar a instalação pronta, confirme:

- login, account, CRM, migrations, criação/edição de Deal e histórico;
- Sidekiq ativo, SMTP, anexos e conexão WebSocket;
- instância WhatsApp conectada e token da account correta;
- mensagem inbound visível em uma lista com filtros apropriados;
- resposta Chatwoot entregue no WhatsApp com status de sucesso;
- mesmo contato/inbox/conversa, sem criar vínculos duplicados indevidamente;
- Calendar/Meet, se habilitado, e isolamento entre usuários/accounts;
- backups fora da máquina e restauração testada.

## Referências

- [Código do fork](https://github.com/RhuanWarles/chatwoot).
- [Deploy Docker do Chatwoot](https://developers.chatwoot.com/self-hosted/deployment/docker).
- [Evolution API — código e configuração](https://github.com/evolution-foundation/evolution-api).
- [Integração Chatwoot — implementação Evolution](https://github.com/evolution-foundation/evolution-api/blob/main/src/api/integrations/chatbot/chatwoot/services/chatwoot.service.ts). Confira o código da tag utilizada; `main` pode ter comportamento diferente.
- [OAuth Web Google](https://developers.google.com/identity/protocols/oauth2/web-server).
