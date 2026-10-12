# Base de conhecimento dos agentes de texto

Em IA → Base de conhecimento, crie uma base da Account e adicione texto manual ou PDF/TXT/MD. Depois selecione as bases na edição do assistente. O Playground usa os mesmos vínculos e mostra os trechos recuperados em “Contexto utilizado”. Sem vínculos, o fluxo anterior continua intacto.

## Configuração e processamento

O PostgreSQL precisa da extensão `vector` (a produção atual já possui pgvector 0.8.7). A migração cria somente quatro tabelas novas, sem índices vetoriais aproximados ou alterações em tabelas de atendimento. O pacote `poppler-utils` na imagem fornece a extração PDF. Sidekiq processa os documentos; não existe OCR, crawler ou integração externa de documentos.

- `SAAS_EMBEDDING_PROVIDER`: `openai` por padrão, único provider desta V1.
- `SAAS_EMBEDDING_MODEL`: `text-embedding-3-small` por padrão; também aceita `text-embedding-3-large`. Ambos usam 1536 dimensões. Trocar o modelo exige reprocessar documentos; a busca exclui documentos indexados com outro modelo.
- `SAAS_EMBEDDING_API_KEY`: credencial opcional específica. Se ausente, reutiliza `SAAS_TEXT_API_KEY` somente quando `SAAS_TEXT_PROVIDER=openai`. Nenhuma chave é exposta na API/frontend.

Uploads: 10 MB; PDF até 200 páginas; texto até 500 mil caracteres; 100 documentos por base; 400 chunks por documento. Chunks de até 2400 caracteres, aproximadamente 600 tokens, com sobreposição de 240 caracteres e corte por espaço quando possível. `token_count` é estimado; o uso faturável vem da resposta do provider. PDFs preservam número de página.

Reindexação marca o documento como processando e mantém os chunks anteriores até a substituição transacional. Falhas deixam status explícito e não participam da busca; é possível tentar novamente. Checksum de texto e modelo evitam re-embedding de conteúdo inalterado. Um identificador de versão impede que jobs antigos sobrescrevam edições recentes.

## Busca, isolamento e custo

Busca exata de cosseno, top 5, similaridade mínima 0,5. Esse threshold é um ponto inicial e deve ser calibrado com perguntas reais. Consulta exige Account correta, bases explicitamente vinculadas/ativas e documentos prontos com o modelo vigente. Dados recuperados são delimitados como referências não confiáveis, com instruções de maior prioridade separadas; histórico atual e fatos explícitos do cliente prevalecem. Instruções não equivalem a uma garantia absoluta de comportamento do LLM.

`Saas::UsageRecord` registra fontes `knowledge_embedding` e `knowledge_retrieval`, provider/model, tokens, status, documento/agente e custo estimado. Não há reserva ou débito comercial adicional. O Playground continua sem débito de wallet. As tarifas iniciais estão em `config/ai_pricing.yml` e precisam acompanhar os preços do provider.

Referências: [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings), [preço do modelo small](https://developers.openai.com/api/docs/models/text-embedding-3-small), [Neighbor](https://github.com/ankane/neighbor).

## Validação

46 exemplos de backend cobrem CRUD, permissões, isolamento, uploads TXT/MD/PDF, chunking, embeddings, custos sem débito, reindexação, exclusão, runtime, Playground, ordem memória/conhecimento/histórico e regressões de Tools. Cinco testes de frontend cobrem formulário do assistente e gerenciamento de bases. Os 12 novos arquivos Ruby passaram no RuboCop. A validação usa PostgreSQL com pgvector em banco local isolado, chaves exclusivamente de teste e cache em memória para o Playground.

O schema foi sincronizado com as migrations já existentes e a migration nova. Isso não altera migrations antigas nem executa `schema:load` em produção. A única migration adicionada nesta implementação cria as quatro tabelas de conhecimento.
