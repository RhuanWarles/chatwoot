# Administração de grupos WhatsApp

## Estado da entrega

Implementação no branch `feat/whatsapp-group-administration`, worktree
`.worktrees/group-administration`. Não houve push, deploy, restart ou mudança
administrativa no grupo real nesta etapa. Não há nova migration ou dependência.

## Interface

Abra uma conversa de grupo e expanda **Participantes do grupo**.
**Informações do grupo** reúne nome, foto, participantes e zona de perigo.
O menu de cada participante oferece promover/rebaixar e remover conforme o
estado atual. A própria instância aparece como **Você**, e administradores
recebem o badge **Admin**. Remover e sair exigem confirmação explícita.

A foto aceita JPEG, PNG e WebP de até 5 MB, com preview separado do avatar salvo.
O backend verifica o conteúdo real e decodifica a imagem com libvips, limitando
a 20 milhões de pixels; envia JPEG normalizado e salva os mesmos bytes após
confirmação remota. URLs temporárias do WhatsApp não são a persistência do avatar.

## Contratos da Evolution confirmados

Consultei a [documentação atual de participantes](https://docs.evolutionfoundation.com.br/evolution-api/update-participant),
[informações do grupo](https://docs.evolutionfoundation.com.br/evolution-api/get-group-info)
e [instâncias](https://docs.evolutionfoundation.com.br/evolution-api/fetch-all-instances).
O índice atual não descreve nome/foto/saída; seus contratos foram confirmados no
[router oficial 2.3.7](https://github.com/EvolutionAPI/evolution-api/blob/2.3.7/src/api/routes/group.router.ts),
[DTOs oficiais](https://github.com/EvolutionAPI/evolution-api/blob/2.3.7/src/api/dto/group.dto.ts)
e no source instalado. Não foram inferidos a partir de nomes.

Todos usam `apikey` somente no backend.

| Operação | Método/rota | Body ou query |
|---|---|---|
| Promover | POST `/group/updateParticipant/{instanceName}` | `{groupJid, action: "promote", participants: [telefone]}` |
| Rebaixar | POST `/group/updateParticipant/{instanceName}` | `{groupJid, action: "demote", participants: [telefone]}` |
| Remover | POST `/group/updateParticipant/{instanceName}` | `{groupJid, action: "remove", participants: [telefone]}` |
| Nome | POST `/group/updateGroupSubject/{instanceName}` | `{groupJid, subject}` |
| Foto | POST `/group/updateGroupPicture/{instanceName}` | `{groupJid, image: "base64 JPEG sem prefixo data:"}` |
| Sair | DELETE `/group/leaveGroup/{instanceName}` | query `groupJid` |
| Estado do grupo | GET `/group/findGroupInfos/{instanceName}` | query `groupJid` |
| Participantes | GET `/group/participants/{instanceName}` | query `groupJid` |
| Própria instância | GET `/instance/fetchInstances` | query `instanceName` |

A versão instalada retorna `{update: "success"}` para nome/foto e
`{groupJid, leave: true}` para saída. Participantes retornam `updateParticipants`;
cada resultado precisa ter status `200`, além do HTTP 201 da operação.
Não há endpoint de exclusão definitiva de grupo no router 2.3.7 consultado.
Nenhuma exclusão/encerramento foi implementada.

## API interna

Prefixo: `/api/v1/accounts/:account_id/conversations/:conversation_id`, usando
o `display_id` nativo da conversa dentro da account.

| Método/rota | Entrada |
|---|---|
| GET `/group` | informações, capacidades, participantes e Contact nativo |
| PATCH `/group` | JSON `{subject}` **ou** multipart com `picture` |
| POST `/group/participants` | `{operation: "promote"/"demote"/"remove", participant_id}` |
| POST `/group/participants` para remover | também exige `confirmed: true` |
| POST `/group/leave` | `{confirmed: true}` |

`participant_id` é o ID real da lista; o servidor consulta novamente os membros,
localiza o participante e usa seu telefone confirmado. LID não vira telefone.
Inboxes, configurações e conversas são consultadas no escopo da account.

## Serviços e permissões

- `Evolution::GroupContext`: centraliza o JID de `contact_inbox.source_id`,
  identidade da instância, estado ativo, consulta de membros e validação de admin.
- `Evolution::GroupInfoService`: dados normalizados e identificação `is_self`.
- `Evolution::GroupParticipantActionService`: remove/promote/demote.
- `Evolution::UpdateGroupSubjectService`: atualiza Contact.name após confirmação.
- `Evolution::UpdateGroupPictureService`: valida/normaliza foto e persiste avatar.
- `Evolution::LeaveGroupService`: confirma saída e registra estado local.
- `Evolution::GroupClient`: mantém ENV/configuração existentes e verifica também
  o resultado individual de cada participante. A adição existente reutiliza isso.

`ConversationGroupPolicy` exige acesso nativo à conversa **e** administrador da
account para ações administrativas. Herda `ConversationPolicy`, incluindo o
overlay Enterprise. O número conectado também precisa ser admin no WhatsApp para
remover/promover/rebaixar/nome/foto; sair exige ser membro. A UI apenas reflete
essas capacidades: as mesmas condições são verificadas pelo backend.

As mutações usam lock da Conversation para serializar ações, inclusive adição.
O servidor rejeita estado inválido, participante ausente, própria conta e criador
`superadmin`. O frontend bloqueia requests duplicadas enquanto envia.

## Cache e sincronização

Todas as mutações invalidam `Evolution::GroupParticipantsService`, inclusive
falhas ambíguas após tentativa remota. Resultados confirmados provocam nova
consulta e substituição da lista, sem otimizar o estado antes de confirmação.
Nome e avatar atualizam o Contact nativo e o store de Conversas/Contatos;
a conversa também é recarregada pelo fluxo nativo, sem F5.

## Após sair

Mensagens, Contact e Conversation são preservados. A Conversation registra
`additional_attributes.evolution_group_left_at` e `evolution_group_left_by_id`.
`can_reply` passa a false, a UI mostra **Você saiu deste grupo** e bloqueia o
composer público. A validação de Message impede novas mensagens públicas;
o endpoint de retry também rejeita reenvios públicos de mensagens antigas.
Anotações privadas e consultas ao histórico continuam disponíveis.
Não há função de reentrada nesta fase.

## Testes executados

- Sintaxe Ruby e compilação dos três componentes Vue envolvidos.
- ESLint dos novos componentes/API, sem erros.
- Serviços com Evolution e registros locais simulados: promover, já admin,
  rebaixar, não admin, remover, removido, ausente, própria instância, permissão,
  grupo inválido, nome em branco, confirmação remota, foto inválida/JPEG gerado,
  cache e saída. Não houve gravação em registros de produção.
- Validação real do modelo contra objetos não salvos: mensagem pública bloqueada,
  nota privada permitida e histórico preservado após marcação em memória.
- Rotas/controllers em processo isolado: confirmação obrigatória, nome inválido,
  payload conflitante, operação inválida, conversa inexistente (422/404).
- Leitura real do grupo de teste na inbox **rhuan**, conversa **54**: endpoint
  retornou 200, própria instância identificada e `superadmin` protegido.
- Testes de estado do frontend: menus contextuais, confirmação antes do request,
  bloqueio de duplo clique, retenção de erro/preview e atualização de store/composer.

Roteiros locais: `tmp/check-group-administration.rb` e `tmp/check-group-admin-ui.cjs`
na raiz do workspace principal. O primeiro roda em processo Ruby isolado com a
mesma versão da aplicação; não publica código. Chamadas de mutação são mocks.

## Validação real pendente de publicação autorizada

Ainda falta publicar e testar pela interface: promover/rebaixar/remover no grupo
real, alterar nome/foto nos dois lados e sair mantendo histórico/composer bloqueado.
Esses itens não foram apresentados como concluídos. A autorização anterior de
deploy do menu não foi reutilizada para esta etapa: o novo pedido exige aprovação.
Preferir o grupo de teste da conversa 54; executar saída por último.

Arquivos desta etapa: services Evolution acima, `GroupParticipantsService`,
`UpdateGroupParticipantService`, policy `ConversationGroupPolicy`, controller
`GroupsController`, controller de participantes, controller de mensagens (retry),
`config/routes.rb`, model `Message`, `MessageWindowService`, `GroupManagementPanel.vue`,
wrapper `GroupParticipantsPanel.vue`, `ReplyBox.vue`, `groupManagementAPI.js`,
traduções EN/PT-BR e este documento. Não houve alteração em CRM ou AI Agents.
