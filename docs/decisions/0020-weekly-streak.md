# 0020 · Sequência semanal

Data: 2026-10-28 · Status: aceita

## Decisão
- Semanas de segunda a domingo, no fuso do aparelho (`session.local_date`).
- A meta da semana é o número de treinos-modelo do arco normal treinado naquela semana (o maior, se houver mais de um).
- Treinos de Manutenção (arco `filler`) contam para a meta. Numa semana só de Manutenção vale a meta do último arco normal; é o caso do título "Sobrevivente do Filler".
- A semana em andamento só soma quando a meta é batida; enquanto não acaba, não quebra a sequência. Uma semana encerrada sem a meta zera a sequência.
- `streak` no TS e `Progression.streak` no Swift rodam `packages/fixtures/streak.json`.

## Consequências
Mudar o número de treinos de um arco muda a meta das semanas passadas dele, já que a meta é derivada. Aceito: arcos raramente mudam depois de começar.
