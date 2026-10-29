# 0029 · Temporadas substituem a Saga

Data: 2026-10-29 · Status: aceita (decisão do Leo, #72). Substitui a Saga anual do modelo inicial.

## Contexto
A Saga era "o ano" e agrupava todos os arcos. Na prática o Leo segue mais de um programa em paralelo (Jiu-Jitsu, Performance), cada um com arcos em sequência, e arcos novos são adicionados no fim conforme o tempo passa.

## Decisão
- A tabela `saga` vira `season` (Temporada): `name`, `position`, `active`. A coluna `year` sai.
- Só uma temporada fica ativa por atleta (índice único parcial `season_one_active_idx`).
- `arc.season_id` e `battle.season_id` passam a aceitar nulo. Arco sem temporada é livre: é a Manutenção (ADR 0028), sempre disponível.
- Liberação em ordem: o arco atual é o primeiro não concluído da temporada ativa. Os seguintes aparecem como BLOQUEADO até o anterior terminar.
- Ativar outra temporada pausa a anterior: o arco atual dela volta para a fila (sem perder a contagem) e o primeiro arco aberto da nova vira atual. Reativar retoma de onde parou.
- O plano inicial local (`StarterPlan.json`) tem `seasons` e `arcs` livres, e a importação é aditiva por nome a cada abertura.
- Migrations: `0005_rename_saga_to_season.sql` no Postgres e `v7_saga_to_season` no SQLite. As duas tiram a temporada dos arcos de Manutenção e ativam a temporada que contém o arco atual.

## Consequências
- A tela de Arcos agrupa por temporada (a ativa primeiro, com o selo ATIVA), mostra "Ativar temporada" nas outras e uma seção "SEMPRE DISPONÍVEL" com os arcos livres.
- A Batalha nova fica na temporada ativa, se houver.
