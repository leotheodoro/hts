# 0016 · Catálogo de exercícios livre com nome normalizado

Data: 2026-10-28 · Status: aceita

## Contexto
Recordes e "Anterior" comparam cargas do mesmo exercício do catálogo. Um catálogo curado exige montar a lista antes de usar; um livre gera duplicatas ("Barra Fixa", "barra fixa").

## Decisão
Catálogo livre por atleta. `exercise.normalized_name` (minúsculas, sem acentos, espaços únicos) é único entre exercícios não excluídos. Ao digitar, o app sugere exercícios existentes e só cria um novo se não houver um com o mesmo nome normalizado. A normalização existe em TS (`normalizeExerciseName`) e Swift (`ExerciseName.normalize`) e roda o mesmo fixture.

## Consequências
Sinônimos diferentes ("Pull-up" e "Barra fixa") continuam sendo exercícios distintos; unir duplicados é ticket futuro.
