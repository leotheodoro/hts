# Plano inicial local

Copie esta pasta para `apps/ios/LocalSeed/` (fora do git) e edite `StarterPlan.json` com o seu programa. Na primeira abertura, se o atleta ainda não tiver arcos (nem no aparelho nem no servidor), o app importa o plano uma vez.

- `kind`: `normal`, `special` ou `filler` (Manutenção sem prazo, ignora `weeks`).
- Blocos: `kind` (`activation`, `strength`, `combo`, `chained_combo`, `fight_round`, `conditioning`, `core`, `mobility`, `cardio`) e `attributes` (`strength`, `power`, `conditioning`, `core`, `mobility`).
- Exercícios: `sets` ("3" ou "3 a 4"), `target` na notação da planilha ("8", "6-6-3-3", "12/12", "30-45 s", "máx"), `unit` (`reps`, `seconds`, `minutes`, `meters`; padrão `reps`) e `restSeconds` opcional.

Programas de preparador costumam ser licenciados: não versione o arquivo real.
