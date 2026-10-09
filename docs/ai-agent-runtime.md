# Primeira execução dos AI Agents

O runtime responde a mensagens públicas de texto de um Contact quando existe um único Agent ativo vinculado à inbox da mesma account. Não executa ferramentas, ações do CRM, áudio, RAG ou integrações externas além da geração OpenAI.

## Configuração

Em AI & Voice, configure texto no modo BYOK com provedor OpenAI e a chave da própria account. A chave continua criptografada no backend. O Agent fornece o modelo, a temperatura e o system prompt. Nesta etapa, o runtime exige BYOK: não utiliza o modo plataforma, que possui cobrança própria em créditos. Outros provedores retornam erro controlado e não enviam resposta.

Em **Configurações → AI Agents**, edite a Larissa (ou outro agente), selecione as **inboxes vinculadas** da própria conta e ative o agente. Marque **Reply in WhatsApp groups** para autorizar respostas em grupos dessas inboxes. A opção começa desmarcada, inclusive para agentes existentes. Sem inbox selecionada, nenhuma conversa é atendida.

A configuração existente impede dois Agents ativos na mesma inbox; o runtime também recusa configurações conflitantes já persistidas. Inboxes com um bot nativo ativo (incluindo Captain) ficam fora deste runtime, evitando respostas concorrentes. Contatos bloqueados e conversas fechadas não recebem respostas automáticas.

## Mensagens e intervenção humana

Uma mensagem recebida enfileira `Saas::AiAgents::RespondJob`. A resposta é criada por `Messages::MessageBuilder`, com os callbacks, broadcasts e envio do canal nativos. O remetente é o Agent, para mostrar seu nome na conversa. `content_attributes` identifica `generated_by_ai`, Agent, mensagem recebida, provedor, modelo, duração e uso de tokens. Não há endpoint paralelo de envio. Excluir o agente preserva as mensagens e seus metadados.

Uma resposta pública manual coloca `Conversation.additional_attributes.ai_agent_state` em `human`, dentro da transação da mensagem. A IA não volta automaticamente após intervenção humana. A resposta automática não pausa o Agent. Notas privadas não interrompem o atendimento.

Estados: `active` permite responder; `paused` e `human` impedem geração. Uma conversa sem estado explícito começa ativa quando possui Agent elegível. Para reativação administrativa explícita, no Rails console:

```ruby
conversation = Account.find(1).conversations.find_by!(display_id: ID_DA_CONVERSA)
conversation.with_lock do
  conversation.update!(additional_attributes: conversation.additional_attributes.merge('ai_agent_state' => 'active'))
end
```

A reativação vale para novas mensagens. Não reenvia automaticamente respostas antigas. A intervenção humana pausa sempre, independentemente do campo de configuração `handoff_enabled`.

## Limites e concorrência

O contexto usa até 30 mensagens públicas, 4.000 caracteres por mensagem e 24.000 caracteres de histórico. O system prompt permanece íntegro. A saída é limitada a 1.024 tokens; o timeout é 60 segundos. Modelos que não aceitam os parâmetros configurados retornam erro controlado, sem substituição silenciosa de modelo.

Um advisory lock PostgreSQL por conversa serializa a geração. O lock de linha da conversa é usado somente ao persistir a resposta ou pausar por intervenção humana. Um cursor persistido impede respostas duplicadas. Mensagens que chegam juntas são consolidadas no contexto mais recente; se surgir nova entrada durante a geração, a resposta antiga é descartada e o job da nova entrada processa o contexto atualizado. Mudanças na configuração do Agent durante a chamada também descartam a resposta antiga.

Timeouts, falhas de conexão, HTTP 429 e 5xx têm até três tentativas. Conversas ocupadas têm até dez tentativas com intervalo de dez segundos. Erros de configuração e respostas vazias não geram mensagem. Logs incluem IDs e códigos sanitizados; não incluem chaves, prompts ou conteúdo da conversa.

## Homologação

Executar os specs de `spec/services/saas/ai_agents` e `spec/listeners/ai_agent_listener_spec.rb` em banco de teste isolado. Após publicação, o administrador escolhe as inboxes da própria conta no editor do agente; nenhuma inbox é selecionada automaticamente pela implantação. Confirmar Agent ativo e chave BYOK, enviar texto de outro WhatsApp e verificar resposta entregue, metadata e ausência de duplicidade. Testar grupo com a opção desativada e ativada. Responder manualmente pelo Chatwoot e enviar outro texto: a IA deve permanecer pausada. Reativar explicitamente e repetir.

O teste real e a entrega pelo canal não podem ser considerados validados apenas com o provider simulado nos specs.

Validação em 09/10/2026: 37 exemplos Rails passaram em PostgreSQL/Redis locais isolados, cobrindo provider, contexto, concorrência em sessões distintas, idempotência, mensagens nativas, intervenção humana, grupos e isolamento por account. Os três testes do formulário passaram; sintaxe Ruby e lint não apresentaram erros. A migração `20261009180000` foi aplicada no banco de teste. Nenhuma chamada real à OpenAI nem mensagem de teste externa foi enviada por essa suíte.
