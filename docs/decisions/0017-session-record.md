# 0017 · Registro de treino: snapshot do plano, recordes e numeração derivados

Data: 2026-10-28 · Status: aceita

## Contexto
O histórico é permanente: editar um treino-modelo não pode alterar sessões já feitas. A issue #3 previa uma tabela `personal_record` e perguntava entre snapshot em JSON e versionamento do treino-modelo.

## Decisão
- **Snapshot em JSON.** Ao iniciar, a sessão guarda em `plan_snapshot` uma cópia do treino-modelo (blocos, exercícios com nome, unidade, séries, alvos e descanso). Os ids apontam para o plano, mas o que a sessão mostra vem do snapshot. Formato: `PlanSnapshot` (Swift) e `PlanSnapshotSchema` (Zod), com ids em minúsculas.
- **Recordes são derivados, sem tabela.** Uma série concluída é Limite Quebrado quando a carga supera todas as séries concluídas anteriores do mesmo exercício do catálogo. Recorde considera só kg (pergunta 5 do handoff); mais reps com a mesma carga fica para depois. Excluir uma sessão recalcula os recordes sem trabalho extra (ADR 0010).
- **Numeração derivada.** "Treino 5 de 6" e "TR 13" saem da ordem de `started_at` entre sessões não excluídas; no arco, contam só as sessões depois de `count_reset_at`.
- **Cargas exatas.** `weight_kg` é `numeric(6,2)` no Postgres e TEXT decimal no SQLite (`Decimal` no Swift). Em `logged_round.weights`, a carga vai como string decimal no JSON.
- **`local_date`.** A sessão guarda o dia no fuso do aparelho, para meta semanal e sequência; os instantes seguem em UTC.
- Só uma sessão em andamento por atleta (índice único parcial nos dois bancos).

## Consequências
Excluir uma sessão renumera as seguintes. A detecção de recorde e o volume viram funções compartilhadas com fixtures no ticket de treino concluído (#9).
