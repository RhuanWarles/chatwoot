# Grupos WhatsApp com Evolution

## Uso

No topo de **Conversas**, use **+ → Novo grupo WhatsApp**, informe nome, inbox e participantes.
Só aparecem inboxes acessíveis ao usuário e configuradas para Evolution.
Na conversa do grupo, abra **Participantes** e use **Adicionar participante**.
É possível buscar contatos nativos ou informar telefone com DDI. LID não é telefone.

As credenciais permanecem no backend: `EVOLUTION_API_URL`, `EVOLUTION_API_KEY` e
`channel.additional_attributes.evolution_instance_name`. O fallback global
`EVOLUTION_INSTANCE_NAME` exige webhook compatível com Evolution.

## Contratos confirmados na Evolution 2.3.7

Criação: `POST /group/create/{instanceName}`

```json
{"subject":"Nome do grupo","participants":["5562994808700"]}
```

Adição: `POST /group/updateParticipant/{instanceName}`

```json
{"groupJid":"120363000000000001@g.us","action":"add","participants":["5562981097573"]}
```

Validação de números: `POST /chat/whatsappNumbers/{instanceName}`, com
`{"numbers":["5562994808700"]}`. Os números canônicos devolvidos pelo WhatsApp são
usados nas operações e na comparação de membros existentes.

Participantes: `GET /group/participants/{instanceName}?groupJid=...`.
O header `apikey` nunca é enviado ao browser. Na versão instalada, criação e
adição respondem HTTP 201. Na adição, cada item de `updateParticipants` também
precisa ter `status: "200"`; HTTP 201 sozinho não significa adição confirmada.

Referências: [criação](https://docs.evolutionfoundation.com.br/evolution-api/create-group),
[adição](https://docs.evolutionfoundation.com.br/evolution-api/update-participant),
[DTO oficial 2.3.7](https://github.com/EvolutionAPI/evolution-api/blob/2.3.7/src/api/dto/group.dto.ts).
O DTO/source confirma o campo `action`, omitido no exemplo da documentação.

## Persistência e recuperação

`Evolution::CreateGroupService` usa `Evolution::GroupRequest`, com chave única
`account_id + request_id` e digest do payload. A tentativa é persistida antes
do POST. O JID remoto é persistido antes de criar os registros locais.

Após confirmação remota, os builders nativos criam/reutilizam Contact,
ContactInbox e Conversation. O `source_id` do ContactInbox é o `groupJid`.
Repetir a mesma solicitação retorna a mesma conversa. Se apenas a persistência
local falhar, a repetição reaproveita o JID e não cria outro grupo.
Timeout ambíguo bloqueia reenvio automático; confira o WhatsApp antes de iniciar
outra solicitação. Não há operação remota idempotente disponível nesse contrato.

`Evolution::UpdateGroupParticipantService` consulta membros atuais, valida
telefones, rejeita duplicados e executa somente `action: add`.
Invalida o cache e consulta novamente `Evolution::GroupParticipantsService`.
O frontend substitui a lista pela resposta confirmada, sem atualização otimista.
As permissões reutilizam InboxPolicy/ConversationPolicy e os registros são
consultados pelo escopo da account atual.

## Validação realizada em 08/10/2026

- Build de produção e ESLint dos componentes/API alterados passaram.
- Testes isolados dos serviços: normalização, LID, duplicados, rejeição por
  participante, cache, isolamento da chave por account, retry, falha local e timeout.
- Testes isolados do estado dos componentes: busca, exclusão de membros existentes,
  telefone manual, remover/selecionar novamente e preservação de formulário/token em erro.
- Teste real autorizado na inbox **rhuan**, id 9, instância **Rhuan**:
  criação com `5562994808700` e adição de `5562981097573` confirmadas pela Evolution.
  Conversa **54**, grupo `120363410418575296@g.us`.
- Retry retornou o mesmo grupo/conversa; GET posterior confirmou cache atualizado;
  duplicado e LID retornaram 422; inbox inexistente retornou 404.
- Não desconectamos uma instância real para testar offline; falhas de rede/timeout
  foram simuladas. Não houve validação visual por uma pessoa no telefone.

## Implantação realizada

Stack existente, sem criar outra. Somente rails/sidekiq recriados.
Fonte de build: `/home/deploy/chatwoot-group-mentions`, preservando o ajuste anterior do Kanban.
Imagem: `chatwoot-saas-ai:production`, digest
`sha256:b8343142361f65843550798ac32e88ab04d306d464e4aa7e8fef07fdd47201aa`.
Migração aditiva: `20261008220000_create_evolution_group_requests.rb`.
Backup protegido: `/home/deploy/whatsapp-groups-backup-20261008`.
Imagem anterior: `chatwoot-saas-ai:before-whatsapp-groups-20261008`.
Health público HTTP 200. Banco, Redis, Evolution, networks, mounts e variáveis preservados.

Para novos deploys, inclua a migration e `lib/custom_exceptions/evolution.rb`
na imagem, aplique migrations antes de ativar o código e preserve os mesmos volumes.
O Dockerfile completo já copia o repositório; o incremental foi ajustado na VPS.
