# Upload de áudio local: HTTP 413

Diagnóstico de 07/10/2026: o envio de MP3/WAV na Conversation #9 retornou
`413 Request Entity Too Large`, conforme Network informado pelo usuário. Não
houve nova mensagem/blob no Rails. O virtual host
`/etc/nginx/sites-enabled/chatwoot.rwhub.com.br` não define `client_max_body_size`,
nem foi encontrada essa diretiva nos arquivos de configuração legíveis incluídos.
O [padrão do Nginx é 1 MB](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size).

O gravador envia arquivos pequenos, enquanto arquivos locais podem exceder esse
limite. O bloqueio ocorre no proxy, antes do parser de attachments do Rails e
antes da Evolution. A inbox API já permite `audio/*`; o backend classifica MIME
`audio/` como `audio`. Não é necessário mudar MIME, formatos, player ou gravador
para corrigir este HTTP 413.

Na produção consultada, `MAXIMUM_FILE_UPLOAD_SIZE=40` e
`DIRECT_UPLOADS_ENABLED=false`: os arquivos seguem por FormData/multipart.

## Correção preparada, ainda não aplicada

Adicionar o conteúdo de `chatwoot-uploads.conf` dentro do `server` HTTPS **somente
do Chatwoot**. O limite de 50 MB é para o corpo HTTP completo, com margem para um
arquivo de até 40 MB e o envelope multipart. Não altera o limite por arquivo
configurado no Chatwoot nem transforma áudio local em voice note.

Depois de autorização, editar o virtual host existente preservando TLS,
proxy, WebSocket e demais configurações. Validar e somente então recarregar:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

Não substituir o virtual host inteiro. Não reiniciar containers, gerar stack ou
alterar banco para aplicar essa diretiva. Para desfazer, remover apenas a linha
adicionada, validar e recarregar novamente.

## Validação após aplicação

- Reenviar o mesmo MP3/WAV na conversa #9: o POST não deve retornar 413.
- Confirmar HTTP de sucesso, attachment `audio`, player e entrega/reprodução no WhatsApp.
- Repetir com OGG/M4A, pelo botão e por drag and drop; registrar MIME e tamanho.
- Conferir um arquivo acima do limite da aplicação e o erro visível.
- Repetir áudio do microfone e áudio com texto, verificando a ordem de entrega.

O frontend foi ajustado para propagar a falha assíncrona até o composer e exibir
uma mensagem específica para HTTP 413. A configuração não foi aplicada à VPS;
entrega real e reprodução dos arquivos locais continuam pendentes dessa etapa.

## Verificações locais

14 verificações isoladas passaram, exercitando os métodos reais extraídos do
source: fila e FormData para MP3/WAV/OGG/M4A, com upload direto e multipart,
propagação de HTTP 413, outros erros, espera assíncrona, limite por arquivo,
rejeição de binário desconhecido e preservação da flag/session do gravador.
O template Vue compilou e as traduções EN/PT-BR foram validadas.
ESLint passou nos dois arquivos de implementação e nos dois arquivos de specs.
Esses testes usam objetos File sintéticos; não comprovam codecs, reprodução,
interação real de drag and drop ou entrega ao WhatsApp.

As regras MIME/extensão não foram ampliadas: os tipos `audio/*` já são aceitos
na inbox API e o bloqueio reproduzido foi de tamanho no proxy. Não foi feita
normalização de arquivos com MIME vazio/genérico nem alteração no backend.

O adaptador Evolution instalado chama `audioWhatsapp` para anexos classificados
como áudio. Esse comportamento existente não foi alterado nesta correção;
o frontend continua deixando `isVoiceMessage: false` para anexos locais.

## Arquivos alterados

- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`:
  mensagem específica para 413 e fila de áudio local sem base64.
- `app/javascript/dashboard/store/modules/conversations/actions.js`:
  retorna a Promise de envio para o composer receber a rejeição.
- `app/javascript/dashboard/i18n/locale/{en,pt_BR}/conversation.json`:
  tradução do erro de upload recusado pelo servidor.
- Specs de `ReplyBox` e de actions de conversations: regressão do erro e fila de áudio.
- `README-DEPLOY.md`, `README_INSTALACAO.md`: limite explícito no exemplo Nginx.
- `deploy/production/nginx/chatwoot-uploads.conf` e este diagnóstico.
