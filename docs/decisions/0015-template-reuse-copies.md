# 0015 · Reaproveitar treino-modelo copia

Data: 2026-10-28 · Status: aceita

## Contexto
Um treino pode ser reaproveitado em outro arco. Compartilhar faria uma edição no arco novo mudar o arco antigo.

## Decisão
Reaproveitar copia o treino-modelo com blocos e prescrições para o arco de destino, com ids novos. `workout_template.source_template_id` aponta para a origem. Cada treino-modelo pertence a um único arco (`arc_id`).

## Consequências
Editar a cópia não afeta o original, e vice-versa. Se um dia for preciso propagar uma mudança, `source_template_id` permite achar as cópias.
