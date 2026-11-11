# 0037 · Treino teste

Data: 2026-11-11 · Status: aceita (decisão do Leo, #216). Complementa a 0035 e a 0036.

## Contexto
Alguns programas do coach têm um teste: um treino que mede uma valência física (o teste inicial do Core Bruto 2.0, o do Power Base Legs). O atleta refaz o teste depois e quer ver a evolução.

## Decisão
- `workout_template.is_test` marca o teste. Ele vem do seed com `"test": true`. O formulário de treino não mexe nesse campo.
- O teste pode ser iniciado sempre, mesmo com o arco bloqueado, concluído ou com a temporada inativa (`ArcService.canTrain(templateId:)`).
- O teste fica fora do rodízio e da contagem do arco. Ele não entra nas letras do `ArcSchedule`, não conta para concluir o arco, não move a última letra do rodízio e não entra no número "Treino N de M". O XP vem normalmente.
- Na lista do arco, o teste vem primeiro, sem letra, com borda `olive-edge`, selo TESTE e "Última vez <data>".
- Ao abrir o teste, a tabela EVOLUÇÃO mostra a vez anterior e a última, lado a lado, com a diferença. O valor de cada exercício é a melhor série concluída: a maior carga, quando houver carga, ou o maior valor na unidade do exercício. Mais é melhor. A melhora aparece em `redText` e a piora em cinza.
- A unidade nova `calories` ("cal") serve para a bike e o remo. O valor fica em `logged_set.reps`, como os minutos ficam em `seconds`. No SQLite a tabela `exercise` é recriada para o CHECK aceitar a unidade nova.

## Consequências
A comparação é só entre as duas últimas vezes; um histórico completo fica para depois. No Core Bruto 2.0, o Teste Inicial vira o teste e o Reteste sai (20 treinos).
