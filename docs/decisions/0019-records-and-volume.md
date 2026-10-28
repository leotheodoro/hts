# 0019 · Limite Quebrado e volume

Data: 2026-10-28 · Status: aceita

## Decisão
- **Volume** de uma sessão = soma de kg × reps das séries concluídas de exercícios por reps. Séries por tempo ou distância e séries sem carga não somam. A conta é exata (decimal), nunca float.
- **Limite Quebrado**: um exercício do catálogo quebra o limite numa sessão quando a maior carga concluída nela supera a maior carga de todas as sessões anteriores. Conta uma vez por exercício por sessão (+25 XP cada).
- **A primeira vez** que um exercício é registrado só define a marca; não é Limite Quebrado. Sem isso, a primeira sessão daria +25 XP por exercício só por existir.
- Tudo é derivado das sessões concluídas, em ordem de início (`progressHistory` no TS e `Progression.history` no Swift, com o fixture `progress-history.json`). Excluir uma sessão recalcula XP, nível, patente e recordes.

## Consequências
Nível e patente do atleta saem do histórico inteiro a cada leitura. Se ficar lento com anos de dados, cache vira decisão nova.
