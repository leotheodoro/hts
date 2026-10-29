# 0030 · Arcos livres só dão XP

Data: 2026-10-29 · Status: aceita (decisão do Leo, #74). Substitui em parte as ADRs 0020, 0021 e 0028.

## Contexto
Os arcos livres (Manutenção e Mobilidade) são um extra: dá para fazer Mobilidade todo dia, independente do arco atual. Se essas sessões contassem para a meta da semana, a meta seria batida sem os treinos do arco.

## Decisão
- Sessões de arcos `filler` dão XP, nível, atributos, recordes e séries de barra fixa, como qualquer sessão.
- Elas não contam para a meta da semana nem para a sequência. `streak` e `titles` (TS e Swift) ignoram as sessões com `weeklyGoal` nulo.
- O título "Sobrevivente do Filler" sai do catálogo, porque uma semana só de Manutenção não mantém mais a sequência.
- Fixtures: `streak.json` e `titles.json`.

## Consequências
Uma viagem com semanas só de Manutenção quebra a sequência. É aceito: a sequência mede o arco.
