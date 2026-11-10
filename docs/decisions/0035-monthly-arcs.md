# 0035 · Arcos mensais abrem juntos depois dos arcos iniciais

Data: 2026-11-10 · Status: aceita (decisão do Leo, #210). Complementa a 0029 e a 0034.

## Contexto
Alguns programas do coach (Jiu-Jitsu, Base Performance) têm duas fases. Primeiro vêm os arcos iniciais, como as duas semanas de adaptação e o pós-adaptação. Depois vêm os treinos por mês (Janeiro e Fevereiro, Julho…). O Leo quer fazer os arcos iniciais em ordem e depois ter todos os meses liberados. Novos meses entram depois, pelo seed.

## Decisão
- O arco tem a coluna `months`, com os meses do calendário (1 a 12) que ele cobre. Ela vem do seed (`"months": [11, 12]`). Um arco sem meses é um arco comum. Só a temporada que o Leo indicar tem arcos mensais.
- Os arcos sem meses seguem a regra da 0029: um por vez, em ordem.
- Os arcos mensais ficam bloqueados até que todos os arcos sem meses da temporada estejam concluídos. A Manutenção não conta. Depois disso, todo mês ainda não concluído fica aberto, e os treinos dele podem ser iniciados. O mesmo vale para um mês que entrar depois pelo seed.
- Continua havendo um só arco atual, por causa do índice `arc_one_current_idx`. Na fase mensal, o arco atual é o mês aberto que cobre o mês do calendário. Se nenhum cobrir, é o primeiro mês aberto. Esse arco aparece como ATUAL e é a sugestão da Home. Os outros meses abertos aparecem como DISPONÍVEL.
- A virada do mês não tem evento. O app alinha o arco atual ao abrir a Home e a aba Arcos (`SeasonService.alignMonthlyArc`), ao concluir um arco e ao ativar a temporada.
- Um mês treinado fora do seu mês do calendário também é concluído ao completar os treinos, e o arco atual não muda.
- O seed nunca deixa um mês como atual. Ele também grava os meses num arco que já existe (por exemplo, "Novembro e Dezembro" da Jiu-Jitsu) e atualiza `server_updated_at` para que o app receba a mudança.

## Consequências
- Migration `0011_add_arc_months` (Postgres, `jsonb`) e `v12_arc_months` (SQLite, JSON em texto). A sincronização leva `months` como JSON.
- O formulário de arco no app não edita meses: eles vêm só do seed.
