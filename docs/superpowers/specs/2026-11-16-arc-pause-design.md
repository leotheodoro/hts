# Pausar o arco atual

Data: 2026-11-16 · Status: aceita

## Por quê

O Leo terminou o Base Volume 1 e o Base Volume 2 começa em 16/11. Nesta semana ele vai fazer o Polimento
Pré-Competição (um arco de Manutenção) em vez do arco atual. Hoje isso custa caro:

- Treino de Manutenção não conta para a sequência (ADR 0030). Uma semana sem treino de arco normal usa a meta do
  último arco (3), não bate e zera a sequência no domingo.
- O prazo do Base Volume 2 (16/11 a 29/11) continua correndo: o arco perde uma semana e aparece como ATRASADO.

Ele quer pausar o arco atual da temporada ativa e retomar quando quiser.

## Objetivos

- Pausar o arco atual da temporada ativa, sem prazo, até tocar em "Retomar arco".
- Semana em que o arco ficou pausado em algum dia não quebra a sequência. Se a meta for batida mesmo assim, a semana
  soma.
- O fim do arco anda o número de dias pausados.
- As pausas ficam no histórico: sequência e prazo continuam derivados dos registros, inclusive depois de retomar.

## Fora do escopo

- Pausar um arco que não é o atual, arcos de Manutenção ou uma temporada inteira.
- Pausa com data de fim marcada ou retomada automática.
- Desfazer uma pausa passada ou editar as datas dela.

## Anti-objetivos

- Esquecer o arco pausado sem perceber: o estado tem que estar visível na Home e na lista de arcos.
- Uma semana pausada voltar a quebrar a sequência depois de retomar, ou em outro aparelho depois da sync.
- Abrir caminho para treinos do arco pausado mexerem na contagem.

## Abordagens

- **A. Tabela `arc_pause` (escolhida).** Um registro por pausa: arco, início, fim (vazio enquanto aberta). Prazo e
  sequência leem as pausas. Uma tabela e uma migration a mais, mas tudo continua derivado do histórico, como o resto
  do app.
- **B. Semanas abonadas do atleta.** Tabela de semanas protegidas, sem ligação com o arco. A sequência fica mais simples,
  mas o prazo ainda precisa dos dias pausados no arco: dois lugares guardando a mesma pausa.
- **Descartada: colunas no arco** (`paused_at` + dias acumulados). Resolve o prazo, mas perde quais semanas foram
  pausadas; a sequência voltaria a quebrar depois de retomar.

O Leo escolheu a A.

## Decidido com o Leo

- Pausa até retomar (não por semana).
- Enquanto pausado: a Home mostra "Arco pausado" com "Retomar arco" no lugar do próximo treino; a Manutenção (e o
  Polimento) continua disponível; os treinos do arco pausado ficam bloqueados.
- Na lista de arcos o arco aparece como PAUSADO (no lugar de ATUAL ou ATRASADO).
- Um dia pausado protege a semana inteira (segunda a domingo). Generoso de propósito.
- Prazo: fim = início + semanas × 7 − 1 + dias pausados. Ex.: fim 29/11, pausado de 16/11 a 23/11 (7 dias) → 06/12.

## Desenho

### Dados

Tabela nova `arc_pause`, no Postgres (Drizzle) e no SQLite, com as convenções do repo (`id` UUIDv7, `athlete_id`,
`created_at`, `updated_at`, `deleted_at`):

| coluna | tipo | |
| --- | --- | --- |
| `arc_id` | uuid → `arc.id` | o arco pausado |
| `start_date` | `date` | dia local em que pausou |
| `end_date` | `date`, nulo | dia local em que retomou; nulo = pausa aberta |

- Sem índice único de pausa aberta: dois aparelhos podem pausar o mesmo arco offline, e a sync não pode falhar por isso.
  Quem lê as pausas trata intervalos sobrepostos como a união deles; retomar fecha todas as pausas abertas do arco.
  (Decisão do Claude.)
- Entra na sync nos dois lados (`TABLES` da API, `SyncService.tables` no app), depois de `arc`.
- Migration no Drizzle, migration no GRDB, `contracts:generate` + `sync:shared`; `SchemaParityTests` cobre.
- "Arco pausado" é derivado (existe pausa aberta), não um novo `arc_status`. O status continua `current`.

### Dias pausados

Uma pausa cobre os dias `start_date` até `end_date − 1` (o dia em que retomou já é treinável). Pausa aberta cobre até
hoje, inclusive. Pausar e retomar no mesmo dia cobre zero dias. Pausar antes do início do arco (ele começa
na segunda depois do anterior, #220) protege a sequência, mas só os dias a partir do início movem o prazo.

### Prazo (`ArcSchedule`)

- `ArcSchedule` recebe as pausas do arco e `today`. Dias pausados = dias cobertos pelas pausas a partir de
  `start_date` do arco (dias pausados antes do início do arco não contam).
- `endDate` soma os dias pausados. Arco pausado nunca está ATRASADO.

### Sequência (TS e Swift juntos)

- `streak(sessions, today, pauses)` no `packages/progression` e `Progression.streak` no `HTSDomain`. `pauses` são
  intervalos `{ startDate, endDate | null }` de todos os arcos do atleta.
- Semana (segunda a domingo) que contém algum dia coberto por pausa: se a meta foi batida, soma; se não, é pulada (não
  zera e não soma). As outras regras do ADR 0020/0030 ficam iguais.
- `thisWeek` continua com feitos e meta.
- Casos novos em `packages/fixtures/streak.json`: semana pausada sem treino no meio de uma sequência; semana pausada
  com a meta batida; pausa aberta na semana em andamento; pausa que atravessa duas semanas; pausar e retomar no mesmo
  dia.
- Os títulos seguem a mesma regra: em `titles()` (TS e Swift), uma semana pausada sem a meta não quebra a corrida do
  "Sequência Acesa". `titles` recebe as pausas e `packages/fixtures/titles.json` ganha um caso. (Decisão do Claude.)
- ADR novo registrando a regra (complementa o 0020).

### Ações (HTSPersistence)

- `ArcService.pause(arcId:)`: só o arco atual, com duração, da temporada ativa, sem pausa aberta. Cria a pausa com
  `start_date` = hoje.
- `ArcService.resume(arcId:)`: fecha a pausa aberta com `end_date` = hoje.
- `canTrain` retorna falso para arco com pausa aberta (os treinos-teste do arco seguem a regra atual deles).
- Qualquer caminho que tira o arco de atual fecha as pausas abertas dele no mesmo dia: desativar ou trocar de
  temporada, `promoteNextArc` e `alignMonthlyArc` (virada do mês na fase mensal, ADR 0035). O lugar natural é
  `SeasonService.makeCurrent` e o `UPDATE` de `activate`/`deactivate`. Assim nenhuma pausa fica aberta num arco da
  fila. Na virada do mês, o arco do mês vira atual sem pausa; se o Leo quiser, pausa de novo. (Decisão do Claude.)
- `pause` recusa enquanto houver um treino em andamento do arco (a tela pede para terminar ou descartar antes). Um
  treino aberto em outro aparelho e concluído durante a pausa conta normalmente: é raro e não vale mudar
  `completedSessions`. (Decisão do Claude.)

### Telas

- Detalhe do arco atual: botão "Pausar arco"; pausado, "Retomar arco".
- Lista de arcos (`ArcRow`): rótulo PAUSADO, que tem prioridade sobre ATRASADO e ATUAL.
- Home: com o arco pausado, o card do próximo treino vira "Arco pausado" com o botão "Retomar arco".
- Textos novos no String Catalog, na voz do design system (verbo no início, sem exclamação).

### API

- Só a sync: a API não calcula sequência nem prazo. Seed não cria pausas.

## Deixado para quem implementa

- O texto exato e o estilo do card de arco pausado na Home e do rótulo PAUSADO, dentro dos tokens.
- Onde o botão de pausar fica no detalhe do arco (seguir o padrão de "Recomeçar contagem").
- Se a pausa precisa de confirmação antes de pausar.
