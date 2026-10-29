# 0021 · Títulos

Data: 2026-10-28 · Status: aceita

## Decisão
Catálogo fixo, derivado das sessões concluídas (nada é gravado). Cada título guarda a data da sessão que o desbloqueou.

| Título | Condição |
| --- | --- |
| Primeiro Treino | 1ª sessão concluída |
| Recrutamento Concluído | a sessão que fechou o primeiro arco concluído |
| Semana Perfeita | primeira semana com a meta batida |
| Sequência Acesa | 4 semanas seguidas com a meta batida |
| Limite Quebrado x10 | 10 Limites Quebrados somados |
| ~~Sobrevivente do Filler~~ (removido em 0030) | semana só de Manutenção que bate a meta, vindo de uma semana batida |
| Cem Barras | 100 séries concluídas de barra fixa (nomes normalizados: barra fixa, barra, pull-up, chin-up) |
| Pronto para a Batalha | a sessão que fechou um arco especial (a Véspera) |

`titles` no TS e `Progression.titles` no Swift rodam `packages/fixtures/titles.json`. O app monta os fatos de cada sessão (meta semanal, recordes, séries de barra, arco fechado) e a função decide os desbloqueios.

## Consequências
Excluir uma sessão pode "tirar" um título. Aceito, como o resto da progressão derivada.
