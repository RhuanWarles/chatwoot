# Retencao de releases na VPS

Regra do usuario: ao preparar/publicar uma nova release com copia de arquivos,
identificar e apagar as copias antigas de releases que nao estejam em uso.

Antes da remocao, verificar mounts Docker, projetos ativos e caminhos de processos
PM2. Nunca apagar bancos, volumes, sessoes, arquivos de configuracao ou fontes
ativas. Validar a nova release antes de remover a copia anterior usada no deploy.
Manter somente a copia necessaria para o trabalho atual; nao acumular diretorios
release/backup de tarefas anteriores.

VPS atual: fontes ativas em /home/deploy/chatwoot-group-mentions; compose existente
em /home/deploy/chatwoot-saas-ai. PitchYes em /home/deploy/Aplicacao_PitchYes.
Limpeza revisada em /home/deploy/cleanup-old-releases.sh. Nao agendar sem revisar
os caminhos e padroes para o estado atual da VPS.
