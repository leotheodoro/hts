# Plano inicial local

Copie esta pasta para `apps/ios/LocalSeed/` (fora do git) e edite `StarterPlan.json` com o seu programa. A cada abertura (depois do sync), o app importa o que ainda não existe, pelo nome: temporadas novas, arcos novos no fim de uma temporada e arcos livres novos. O que já existe não é alterado.

- `seasons`: temporadas em ordem, cada uma com `name` e `arcs` em ordem. A primeira temporada criada fica ativa; dentro dela, o primeiro arco não concluído é o atual e os seguintes ficam bloqueados (docs/decisions/0029).
- `arcs` (no topo): arcos livres, fora de qualquer temporada e sempre disponíveis. São sempre Manutenção (`filler`).

- `kind` (arco de temporada): `normal`, `special` ou `filler` (Manutenção sem prazo, ignora `weeks`).
- Blocos: `kind` (`activation`, `strength`, `combo`, `chained_combo`, `fight_round`, `conditioning`, `core`, `mobility`, `cardio`) e `attributes` (`strength`, `power`, `conditioning`, `core`, `mobility`).
- Exercícios: `sets` ("3" ou "3 a 4"), `target` na notação da planilha ("8", "6-6-3-3", "12/12", "30-45 s", "máx"), `unit` (`reps`, `seconds`, `minutes`, `meters`; padrão `reps`) e `restSeconds` opcional.

Programas de preparador costumam ser licenciados: não versione o arquivo real.
