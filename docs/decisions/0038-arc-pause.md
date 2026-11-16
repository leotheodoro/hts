# 0038 · Pausar o arco atual

Data: 2026-11-16 · Status: aceita · Complementa 0020 e 0030

## Contexto
Numa semana de polimento pré-competição o atleta treina só Manutenção, que não conta para a sequência (0030). A
semana fechava sem a meta e zerava a sequência; o prazo do arco atual continuava correndo (#222).

## Decisão
- O atleta pausa o arco atual da temporada ativa até retomar. Cada pausa é uma linha em `arc_pause` (`start_date`,
  `end_date` nulo enquanto aberta), sincronizada.
- Uma pausa cobre `start_date` até `end_date − 1`; aberta, cobre até hoje. Pausar e retomar no mesmo dia cobre nada.
  Pausas sobrepostas contam uma vez.
- Sequência: uma semana com algum dia coberto, encerrada sem a meta, não zera e não soma. Com a meta batida, soma.
  O título Sequência Acesa segue a mesma regra.
- Prazo: o fim do arco anda os dias pausados a partir do início do arco. Arco pausado nunca está atrasado.
- Treinos do arco pausado ficam bloqueados; a Manutenção continua disponível. Qualquer caminho que tira o arco de
  atual fecha as pausas abertas dele no mesmo dia.
- `streak` e `titles` (TS e Swift) recebem as pausas e rodam `packages/fixtures/streak.json` e `titles.json`.

## Consequências
Um dia pausado protege a semana inteira, de propósito: evita meta proporcional em semana parcial.
