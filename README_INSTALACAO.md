# Instalação e operação — Chatwoot com CRM

Guia deste projeto customizado, com Deals, Pipelines, Custom Fields, Activities, histórico e integração Google Calendar/Meet. A instalação recomendada usa Docker Compose em Linux. Windows e macOS podem usar Docker Desktop; para desenvolver Rails no Windows, prefira WSL2. Serviços gerenciados também podem ser usados, desde que ofereçam os mesmos processos e armazenamento descritos aqui.

**Use o código completo deste fork.** A imagem oficial do Chatwoot não inclui automaticamente as customizações do CRM. Não copie somente os arquivos Vue: controllers, models, policies, migrations, traduções e jobs também são necessários.

## 1. O que precisa existir

| Componente | Função | Persistência |
|---|---|---|
| Rails | Interface, API, WebSocket e webhooks | Uploads em `/app/storage` |
| Sidekiq | Jobs, notificações e sincronização de reuniões | Usa PostgreSQL e Redis da mesma instalação |
| PostgreSQL com pgvector | Contas, contatos, conversas, mensagens, CRM e tokens criptografados | Volume ou banco gerenciado |
| Redis | Filas e comunicação entre processos | Volume; manter configuração de durabilidade adequada |
| Proxy com HTTPS | Domínio público e WebSocket | Certificados e configuração do proxy |
| Evolution API, opcional | Integração WhatsApp | Banco e volume próprios, separados do Chatwoot |

Planeje capacidade conforme usuários, anexos e histórico. O build exige mais memória e disco que o uso cotidiano. Como ponto de partida operacional, reserve 4–8 GB de RAM e espaço suficiente para código, dependências, imagens, banco, anexos e backups; isso não é garantia de capacidade. Pode-se compilar em outra máquina/CI e publicar a imagem em um registry.

Instale Git, Docker Engine e o plugin Docker Compose v2. Confira:

```sh
git --version
docker version
docker compose version
df -h
```

## 2. Obter o projeto certo

```sh
git clone <URL_DO_SEU_FORK> chatwoot-crm
cd chatwoot-crm
git checkout <BRANCH_OU_TAG_DA_VERSAO_COMPLETA>
git status --short
```

Antes de trocar de máquina, confirme que todas as customizações estão commitadas e enviadas ao seu fork. Arquivos não rastreados na VPS **não aparecem em um clone**. Não versionar `.env`, dumps, chaves SSH, tokens ou credenciais OAuth.

Neste snapshot, `.ruby-version` indica Ruby 3.4.4, e `docker/Dockerfile` usa Node 24 e pnpm 10.2.0. Para outras revisões, os arquivos do projeto são a referência. Não atualizar dependências como parte de uma simples implantação.

## 3. Configurar o ambiente

```sh
cp .env.example .env
chmod 600 .env
```

Edite `.env` com valores próprios:

```dotenv
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
FRONTEND_URL=https://atendimento.exemplo.com
DEFAULT_LOCALE=pt_BR
FORCE_SSL=true
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
ENABLE_ACCOUNT_SIGNUP=false

SECRET_KEY_BASE=<SEGREDO_HEXADECIMAL_LONGO>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<CHAVE_PRIMARY>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<CHAVE_DETERMINISTIC>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<SALT>

POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=<SENHA_FORTE>
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=<OUTRA_SENHA_FORTE>
ACTIVE_STORAGE_SERVICE=local
```

Gere valores novos para uma instalação nova. Com OpenSSL disponível, `openssl rand -hex 64` gera um segredo hexadecimal. Para as chaves de criptografia, use o gerador Rails depois do build:

```sh
docker compose -p chatwoot-crm -f compose.portable.yaml run --rm --no-deps rails bundle exec rails db:encryption:init
```

Copie as três chaves geradas para `.env` antes de iniciar o uso das integrações. Não use o valor de exemplo como chave real. **Em migrações de uma instalação existente, preserve SECRET_KEY_BASE e as três chaves de criptografia originais.** Gerar novas chaves torna os dados criptografados existentes ilegíveis.

Para acesso local sem proxy, use `FRONTEND_URL=http://localhost:3000` e `FORCE_SSL=false`. Não deixe HTTP local como callback de uma instalação pública.

## 4. Compose independente da VPS

O `compose.yaml` da VPS atual usa uma rede externa da Evolution. Para um ambiente novo, crie `compose.portable.yaml` com o exemplo abaixo. Os comandos deste guia usam sempre o mesmo nome de projeto, `chatwoot-crm`, para manter os volumes consistentes.

```yaml
services:
  rails:
    image: chatwoot-crm:local
    build:
      context: .
      dockerfile: docker/Dockerfile
    env_file: .env
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - storage_data:/app/storage
    environment:
      RAILS_ENV: production
      NODE_ENV: production
      INSTALLATION_ENV: docker
      PIDFILE: /tmp/chatwoot-server.pid
    entrypoint: /app/docker/entrypoints/rails.sh
    command: [bundle, exec, rails, s, -p, "3000", -b, "0.0.0.0"]

  sidekiq:
    image: chatwoot-crm:local
    env_file: .env
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    volumes:
      - storage_data:/app/storage
    environment:
      RAILS_ENV: production
      NODE_ENV: production
      INSTALLATION_ENV: docker
    command: [bundle, exec, sidekiq, -C, config/sidekiq.yml]

  postgres:
    image: pgvector/pgvector:pg16
    env_file: .env
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DATABASE}
      POSTGRES_USER: ${POSTGRES_USERNAME}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    env_file: .env
    restart: unless-stopped
    command: [sh, -c, 'exec redis-server --appendonly yes --requirepass "$${REDIS_PASSWORD}"']
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
  storage_data:
```

Não publique PostgreSQL ou Redis na internet. Se usar banco gerenciado, ajuste host, usuário, senha, database e SSL em `config/database.yml`/variáveis compatíveis com o projeto e remova o serviço local correspondente. Se existir `DATABASE_URL`, verifique-a: ela pode prevalecer sobre as variáveis individuais. Senhas em URLs precisam de percent-encoding.

## 5. Build, banco e inicialização

```sh
docker compose -p chatwoot-crm -f compose.portable.yaml config --quiet
docker compose -p chatwoot-crm -f compose.portable.yaml build rails
docker compose -p chatwoot-crm -f compose.portable.yaml up -d postgres redis
docker compose -p chatwoot-crm -f compose.portable.yaml run --rm rails bundle exec rails db:chatwoot_prepare
docker compose -p chatwoot-crm -f compose.portable.yaml up -d rails sidekiq
docker compose -p chatwoot-crm -f compose.portable.yaml ps
```

Espere PostgreSQL aceitar conexões antes de preparar o banco. `depends_on` sozinho não garante prontidão. A preparação deve incluir as migrations do CRM presentes no fork. Rails e Sidekiq precisam usar a mesma imagem e as mesmas chaves.

O Dockerfile compila os assets de produção. Alterar Vue/Tailwind e executar somente `docker restart` **não recompila o frontend**. Não publicar builds de desenvolvimento nem depender do Vite dev server em produção.

Para permitir o cadastro inicial pelo navegador, habilite temporariamente `ENABLE_ACCOUNT_SIGNUP=true`, recrie Rails com a nova configuração e complete o onboarding. Depois desabilite e recrie novamente. Para administração da instalação, atribua o tipo de Super Admin ao usuário correto pelo console, após conferir o e-mail:

```sh
docker compose -p chatwoot-crm -f compose.portable.yaml exec rails bundle exec rails console
```

```ruby
user = User.find_by!(email: 'admin@exemplo.com')
user.update!(type: 'SuperAdmin')
```

Administrador de uma account e Super Admin da instalação são permissões diferentes. O painel global fica em `/super_admin`.

## 6. Domínio, HTTPS e proxy

Crie o DNS do domínio para o servidor. Configure TLS válido e encaminhe tráfego ao Rails. Em Nginx instalado no host, o destino pode ser `127.0.0.1:3000`. Exemplo do bloco dentro de um servidor HTTPS já configurado:

```nginx
# Dentro do server HTTPS do Chatwoot: 40 MB por arquivo + envelope multipart.
client_max_body_size 50m;

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

Configure certificados, redirecionamento HTTP→HTTPS e limite de upload de acordo com seu proxy. Se Nginx/Traefik/Caddy também estiver em Docker, `localhost` aponta para o próprio proxy: conecte-o à rede da aplicação e use `http://rails:3000`. Confira WebSocket em `/cable`.

Com Cloudflare, mantenha HTTPS válido também na origem e use Full (strict). Não cachear API, páginas autenticadas ou callbacks OAuth. Não bloquear webhooks necessários com desafios interativos. `FRONTEND_URL` deve ser a URL pública real, mesmo quando uma integração usa URLs Docker internamente.

## 7. E-mail / SMTP

Configure as variáveis já existentes em `.env.example`, por exemplo:

```dotenv
MAILER_SENDER_EMAIL=Atendimento <atendimento@exemplo.com>
SMTP_ADDRESS=smtp.exemplo.com
SMTP_PORT=587
SMTP_DOMAIN=exemplo.com
SMTP_USERNAME=<USUARIO_SMTP>
SMTP_PASSWORD=<SENHA_SMTP>
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

Use TLS e porta exigidos pelo provedor; não combinar configurações incompatíveis de SSL direto e STARTTLS. Configure SPF/DKIM/DMARC com seu provedor. SMTP envia notificações e e-mails do sistema. Para atender clientes por e-mail, crie também uma inbox de e-mail em **Configurações → Caixas de Entrada** e configure recebimento conforme o canal escolhido. Sidekiq deve estar ativo.

## 8. Google Cloud, Calendar e Meet

1. Crie/selecione um projeto Google Cloud e habilite **Google Calendar API**.
2. Configure a tela de consentimento OAuth. Em modo Testing, adicione os e-mails que conectarão como usuários de teste.
3. Crie um cliente OAuth do tipo **Aplicativo da Web**. Uma chave JSON de service account não substitui esse cliente.
4. Cadastre a URI exata: `https://atendimento.exemplo.com/crm/google_calendar/callback`. Sem barra extra e com o domínio real.
5. No Super Admin, configure `GOOGLE_OAUTH_CLIENT_ID` e `GOOGLE_OAUTH_CLIENT_SECRET`. As configurações globais salvas prevalecem sobre ENV. Preserve callbacks adicionais de login Google/Gmail, caso também utilize essas integrações; o callback do Calendar não substitui os demais.
6. Acesse **Configurações → Integrações → Google Calendar** e conecte sua conta pessoal Google.

Os scopes deste CRM são `openid`, `email` e `https://www.googleapis.com/auth/calendar.events.owned`. Cada usuário conecta sua própria conta dentro da account. O calendário usado é o principal da conta conectada.

Na Activity de Reunião, informe data/hora, duração e participantes; habilite Google Calendar e, opcionalmente, Meet. O responsável deve ser o usuário conectado. A atividade local é salva antes da sincronização em Sidekiq. **Confirme “Sincronizado” e o link “Abrir no Google Calendar”**; criar uma Activity local, sozinho, não confirma criação no Google nem aceite dos convidados.

Erros comuns: `403 access_denied` em Testing indica conferir usuários de teste; `redirect_uri_mismatch` exige callback idêntico; conexão indisponível exige conferir Client ID/Secret e chaves de criptografia. Apps externos em Testing que pedem scopes de Calendar normalmente recebem refresh tokens com validade de sete dias. Planeje publicação/verificação conforme as regras do Google.

Detalhes da implementação: [Google Calendar e Meet](docs/crm/google-calendar.md). Referências oficiais: [OAuth Web](https://developers.google.com/identity/protocols/oauth2/web-server), [scopes de Calendar](https://developers.google.com/workspace/calendar/api/auth), [expiração de tokens](https://developers.google.com/identity/protocols/oauth2).

## 9. Evolution API / WhatsApp

Evolution é um serviço separado. Preserve seu próprio `DATABASE_CONNECTION_URI`, Redis, API key e volume de instâncias. Neste ambiente a versão validada foi v2.3.7; isso não afirma que seja a versão mais recente ou que qualquer outra versão seja compatível.

Na integração Chatwoot da instância Evolution, configure URL do Chatwoot, account ID, token de acesso de um usuário autorizado, inbox/canal e demais opções da versão instalada. Copie o webhook gerado pela integração para a inbox API quando necessário. Não inventar IDs: eles mudam entre instalações.

Para comunicação Docker interna, use `http://rails:3000` somente quando Evolution compartilha a rede e esse alias resolve. Se a Evolution precisar importar histórico/atualizar `source_id` diretamente no banco, configure:

```dotenv
CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=postgresql://USUARIO:SENHA_URL_ENCODED@chatwoot-postgres:5432/chatwoot?sslmode=disable
```

`chatwoot-postgres` é um exemplo de alias DNS, que precisa existir na rede compartilhada. Use as credenciais reais do Chatwoot; **não substituir o banco principal da Evolution por essa URI**. `sslmode=disable` corresponde ao PostgreSQL interno sem TLS deste exemplo; banco gerenciado pode exigir SSL.

Para uma rede dedicada, declare-a como externa nos dois Composes e conecte Rails e, apenas quando necessário, PostgreSQL a ela. Dê aliases exclusivos, como `chatwoot-web` e `chatwoot-postgres`, evitando colisões com outro serviço chamado `postgres`. Crie a rede antes do deploy. Uma conexão feita apenas com `docker network connect` pode desaparecer ao recriar o container; registre a rede no Compose/stack.

Teste DNS/TCP de dentro da Evolution e, em seguida, autenticação no banco. Nunca deixar um placeholder literal `host` na URI: ele causou `getaddrinfo EAI_AGAIN host` nesta instalação. Proteja o token Chatwoot e a senha PostgreSQL como segredos.

Mudanças em ENV exigem recriar/redeployar o serviço com **mesmos banco, volumes e redes**. `docker restart` não recarrega a configuração ENV do Compose. Não apagar sessão WhatsApp para resolver DNS.

### Mensagens existem, mas conversa não aparece

Verifique **status e atribuição**: a lista “Abertas” exclui `pending`, e “Minhas” exclui conversas sem responsável. Use “Todos”/“Não atribuídas” conforme o objetivo. `conversationPending=false` na Evolution não garante conversão retroativa de conversas antigas pendentes. Adicione o usuário aos membros da inbox e confira `account_id`/`inbox_id` reais.

A API de conversa usa `display_id` na rota `/api/v1/accounts/ACCOUNT/conversations/DISPLAY_ID`, que pode diferir do ID interno do PostgreSQL.

## 10. Portainer

Cadastre uma stack com o Compose e suas variáveis, ou use um fluxo Git controlado. Não colocar senhas no repositório. O contexto de build precisa estar disponível onde o Compose executa; uma stack criada somente pelo editor não garante acesso ao código fonte. Para deployment via Portainer, pode ser mais simples construir a imagem em CI e usar sua tag em Rails e Sidekiq, sem `build`.

Não renomear projeto/stack nem volumes numa atualização sem mapear os volumes existentes. Isso pode fazer a instalação parecer vazia por criar volumes novos, embora os antigos ainda existam. A definição da stack, não um arquivo alterado dentro do container, deve ser a fonte durável das variáveis.

## 11. Atualização e rollback

Faça backup antes de migrations. Use tags imutáveis ou registre o digest da imagem anterior. Para atualizar código:

```sh
git pull --ff-only
docker compose -p chatwoot-crm -f compose.portable.yaml build rails
docker compose -p chatwoot-crm -f compose.portable.yaml run --rm rails bundle exec rails db:chatwoot_prepare
docker compose -p chatwoot-crm -f compose.portable.yaml up -d --no-deps rails sidekiq
```

Planeje janela/ordem de deploy quando migrations não forem compatíveis com a versão anterior. Rollback da imagem não desfaz migrations; confira compatibilidade antes de voltar. Nunca usar `docker compose down -v`, reset de banco ou remoção de volumes para atualizar.

Imagens não usadas podem ser removidas com `docker image prune -a`, após conferir também containers parados e a política de rollback. Isso pode remover imagens mantidas como rollback e não equivale a limpar backups, volumes ou cache de build. Não executar `docker system prune --volumes` como manutenção automática.

## 12. Backup e migração de servidor

Salve separadamente: dump PostgreSQL, uploads/storage, `.env`, chaves de criptografia, configurações globais, Compose/proxy e a versão completa do código/imagem. Evolution precisa de backup próprio de banco, sessões e configuração.

Exemplo de dump, em terminal Linux/WSL:

```sh
mkdir -p backups
chmod 700 backups
docker compose -p chatwoot-crm -f compose.portable.yaml exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > backups/chatwoot.dump
chmod 600 backups/chatwoot.dump
```

Para backup consistente de banco e anexos, suspenda escritas/jobs durante a captura ou use estratégia de snapshots coordenados. Copie o conteúdo do volume `storage_data`; não basta copiar a imagem Docker. Armazene backups criptografados fora do servidor e teste restauração.

No destino, configure a mesma versão, preserve chaves e restaure o dump em banco vazio antes de iniciar Rails/Sidekiq. Exemplo após criar o PostgreSQL de destino:

```sh
docker compose -p chatwoot-crm -f compose.portable.yaml exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges' < backups/chatwoot.dump
```

Restaure uploads, ajuste domínio/DNS/callbacks e teste. Não usar `--clean` sobre um banco existente sem planejamento. Confirme compatibilidade de versões PostgreSQL/pg_dump/pg_restore. Copiar diretamente diretórios de dados entre versões major diferentes não é uma migração válida.

## 13. Desenvolvimento local

Use Ruby indicado em `.ruby-version`, Node/pnpm do projeto e PostgreSQL/Redis locais ou Docker. No WSL/Linux, inicialize rbenv antes de comandos Ruby:

```sh
eval "$(rbenv init -)"
bundle install
pnpm install --frozen-lockfile
bundle exec rails db:chatwoot_prepare
pnpm dev
```

Configure `.env` para development e host/portas reais dos serviços. Use `Procfile.dev`/Overmind; worktrees deste projeto devem ter banco, portas e Redis separados conforme `.codex/environments/environment.toml`, quando disponível. Não conectar o ambiente de desenvolvimento ao banco de produção.

## 14. IA e voz, opcionais

Não são necessárias para CRM, inbox ou Calendar. Se o módulo estiver presente nesta revisão, configure as chaves de criptografia e siga [SaaS AI & Voice](docs/saas-ai-voice.md) para provedores de texto, Vapi, webhook público, vínculos por account e créditos. Os exemplos desse documento não incluem credenciais reais nem autorizam disparar chamadas em produção.

## 15. Checklist de entrega e diagnóstico

- Rails e Sidekiq online usando a mesma imagem; PostgreSQL e Redis acessíveis.
- Login, envio de e-mail, upload e WebSocket funcionando.
- CRM: criar Deal, trocar Pipeline/Etapa, conferir histórico, Custom Fields e Activities.
- Calendar: conectar conta real, criar reunião, confirmar sincronização/Meet e testar cancelamento.
- Evolution: inbound e outbound, status da mensagem, membros da inbox e filtros da lista.
- Reiniciar/redeployar sem perder contas, anexos ou sessões; validar restauração em ambiente separado.

```sh
docker compose -p chatwoot-crm -f compose.portable.yaml logs --tail=100 rails sidekiq
docker compose -p chatwoot-crm -f compose.portable.yaml exec postgres pg_isready
docker compose -p chatwoot-crm -f compose.portable.yaml exec rails bundle exec rails db:migrate:status
df -h
docker system df
```

Não compartilhar logs completos ou `docker inspect` sem remover segredos. Tela antiga após deploy: confira manifest/assets da imagem servida e recarregue o navegador. Jobs parados: confira Sidekiq, Redis e credenciais. Banco aparentemente vazio: confira nome do projeto, volumes e URI antes de criar/seed/resetar qualquer coisa.

Referências: [código e documentação oficiais do Chatwoot](https://github.com/chatwoot/chatwoot), [variáveis oficiais](https://github.com/chatwoot/chatwoot/blob/develop/.env.example). As instruções específicas de CRM deste README vêm do fork e precisam acompanhar a revisão implantada.
