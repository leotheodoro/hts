# 0014 · Alvos de série como JSON tipado

Data: 2026-10-28 · Status: aceita

## Contexto
As planilhas usam alvos em vários formatos: `3 × 8`, `6-6-3-3`, `12/12`, `10-20 s`, `máx`, e séries em faixa (`3 a 4`). Uma coluna numérica de reps não comporta isso.

## Decisão
`prescribed_exercise.targets` é uma lista de alvos (`jsonb` no Postgres, JSON em TEXT no SQLite). Cada alvo é `{"type":"fixed","value":8}`, `{"type":"range","min":10,"max":20}` ou `{"type":"max"}`, na unidade do exercício (reps, segundos, metros, minutos). A lista tem um alvo para todas as séries ou um por série até `sets_max`. Séries em faixa usam `sets_min` e `sets_max`. "Por lado" (`12/12`) é propriedade do exercício (`per_side`).

Tipos: `SetTarget` em `HTSDomain` e `SetTargetSchema` (Zod) em `apps/api/src/db/targets.ts`, com o mesmo JSON.

## Consequências
Novos formatos entram como novo `type`, sem migration. Consultas SQL por alvo ficam mais difíceis, o que não é um uso previsto. Ler e escrever a notação da planilha é do ticket de criar treino-modelo (#5). "15 a 20" é sempre faixa, e é assim que uma faixa é mostrada; "15-20" com 2 séries é a lista por série (#75).
