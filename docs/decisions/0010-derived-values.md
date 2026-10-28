# 0010 · Valores de progressão são derivados

Data: 2026-10-28 · Status: aceita

## Contexto
Excluir uma sessão precisa recalcular XP, recordes e sequência. Guardar agregados cria risco de divergência.

## Decisão
XP total, nível, patente, atributos e sequência não são colunas. São calculados a partir dos registros pelas funções de `packages/progression` (TS) e `HTSDomain` (Swift). As duas implementações rodam os mesmos casos de `packages/fixtures`.

## Consequências
Mudança de regra de progressão vale para o histórico inteiro. Se o cálculo ficar caro, cache é decisão nova.
