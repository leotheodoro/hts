# 0036 · Arcos sem fim e desativar temporada

Data: 2026-11-11 · Status: aceita (decisão do Leo, #214). Complementa a 0029 e a 0034.

## Contexto
Alguns programas do coach (Power Building) não têm data final: o atleta faz o mesmo arco enquanto quiser. Ele sai desse arco quando ativa outra temporada ou quando para de seguir a temporada.

## Decisão
- Um arco sem fim é um arco comum (`kind` normal) sem `weeks` e sem `start_date`. Ele vem do seed com `"endless": true`, que não aceita `weeks` nem `months`.
- Esse arco segue a regra que já valia para arco sem duração: nunca é concluído, nunca fica atrasado, mostra "N treinos · sem prazo" e não tem barra de progresso. Enquanto a temporada estiver ativa, ele fica como arco atual, e a Home sugere os treinos em rodízio (A, B, A…).
- "Desativar temporada" fica na página da temporada ativa, com a mesma confirmação da troca. Ao desativar, nenhuma temporada fica ativa. O arco atual volta para a fila e a contagem dele recomeça, como numa troca (0034). XP, nível e treinos feitos continuam. Ao ativar a temporada de novo, ela continua desse arco.
- Sem temporada ativa, a aba Arcos mostra só os arcos livres, com um aviso para ativar uma temporada. A Home fica sem próximo treino. A Manutenção continua liberada.

## Consequências
Nenhuma coluna nova. O formulário de arco (escondido, #64) sempre dá duração a um arco comum: editar um arco sem fim por ele daria semanas a esse arco.
