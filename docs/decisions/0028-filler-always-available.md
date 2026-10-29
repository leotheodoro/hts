# 0028 · Manutenção sempre disponível

Data: 2026-10-29 · Status: aceita (decisão do Leo, #70)

## Decisão
- Só existe um arco atual por vez, e ele nunca é de Manutenção (`filler`).
- Arcos de Manutenção ficam fora da fila: não viram atuais ao serem criados nem são promovidos quando um arco normal termina. A lista os mostra como "SEMPRE DISPONÍVEL".
- A aba Status mostra o próximo treino do arco atual (ação principal, em `blood`) e, separado, um card Manutenção com todos os treinos dos arcos de Manutenção, cada um com "Iniciar" (fantasma).
- Treinos de Manutenção contam para a sequência como antes (ADR 0020) e não mexem na rotação A-B-C do arco atual.
- Migration local `v6_filler_never_current` tira do posto de atual um arco de Manutenção criado antes desta regra e atualiza `updated_at` para a correção sincronizar.
