# 0023 · Atributos com nível próprio

Data: 2026-10-28 · Status: aceita (decisão do Leo, #14)

## Decisão
Cada atributo (FOR força, EXP explosão, GÁS resistência, COR core, MOB mobilidade) tem nível próprio, na mesma curva de nível do atleta (`progression.json`). Cada série concluída dá o XP de série (10) a cada atributo do bloco dela; um bloco com dois atributos alimenta os dois. Os atributos vêm do snapshot da sessão.

`attributeLevels` no TS e `Progression.attributeLevels` no Swift rodam `packages/fixtures/attribute-levels.json`.

## Consequências
Os níveis de atributo são independentes do nível do atleta e sobem mais devagar. Rounds de Luta ainda não contam (ver issue de XP do Round de Luta).
