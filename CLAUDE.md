# Hard To Submit (HTS)

## Produto

- App iOS nativo para registrar treinos de preparação física para jiu-jitsu, série por série, com timer de descanso.
- Camada de progressão: cada série concluída vira XP, nível, patente (E a S) e atributos (FOR, EXP, GÁS, NÚC, MOB).
- O atleta organiza o ano em uma saga de arcos; cada arco tem treinos-modelo e uma duração em semanas.
- Offline-first: o app grava no SQLite local e sincroniza com a API (Postgres) depois.
- Hoje é um atleta só, mas todo dado já é multiusuário (`athlete_id`).

Fontes de verdade: `docs/product/handoff-produto.md` (comportamento), `docs/design/design-system.md` (visual e voz), `packages/design-tokens/tokens.json` (tokens), `docs/decisions/` (ADRs).

## Glossário (nome no código)

| Produto (pt-BR) | Código |
| --- | --- |
| Saga | `Saga` |
| Arco | `Arc` |
| Treino-modelo | `WorkoutTemplate` |
| Bloco | `Block` |
| Exercício (catálogo) | `Exercise` |
| Exercício prescrito | `PrescribedExercise` |
| Treino / sessão | `Session` |
| Série feita | `LoggedSet` |
| Round registrado | `LoggedRound` |
| Recorde (Limite Quebrado) | `PersonalRecord` |
| Batalha | `Battle` |
| Título | `Title` |
| Patente | `Rank` |
| Atributo | `Attribute`: FOR=`strength`, EXP=`power`, GÁS=`conditioning`, NÚC=`core`, MOB=`mobility` |
| Sequência | `Streak` |
| Atleta | `Athlete` |

Código, tabelas e identificadores em inglês. Textos de interface em pt-BR, no String Catalog (`apps/ios/HTS/Resources/Localizable.xcstrings`).

## Mapa do repo

```
apps/api/                 API Hono + Drizzle (Postgres). src/, drizzle/ (migrations), Dockerfile
apps/ios/project.yml      Projeto XcodeGen (o .xcodeproj não é versionado)
apps/ios/HTS/             Target do app: App, navegação, telas. Fino.
apps/ios/HTSKit/          Swift Package local
  HTSDesign               Tokens gerados, fontes, NotchShape, NotchCard, HTSButton
  HTSDomain               Tipos e regras puras (progressão). Sem UI, sem banco
  HTSPersistence          GRDB, migrations, repositórios, UUIDv7
  HTSAPI                  Cliente gerado do OpenAPI
packages/design-tokens/   tokens.json + gerador (Tokens.swift)
packages/progression/     progression.json + lógica TS
packages/contracts/       openapi.json gerado pela API
packages/fixtures/        Casos compartilhados TS/Swift ({ input, expected })
scripts/sync-shared.ts    Gera tokens e copia arquivos compartilhados para o HTSKit
docs/decisions/           ADRs
```

## Comandos

```
pnpm install                     dependências TS
pnpm dev                         API em http://localhost:8787
pnpm test | pnpm lint | pnpm typecheck
pnpm sync:shared                 gera Tokens.swift e copia progression.json, fixtures e openapi.json
pnpm --filter api db:generate    nova migration a partir de src/db/schema.ts
pnpm --filter api db:migrate     aplica as migrations
pnpm --filter api contracts:generate   openapi.json + db-schema.json em packages/contracts
docker compose up -d             Postgres local (porta 5442 no host)
make ios-generate | make ios-test | make ios-build
```

Depois de mudar tokens.json, progression.json, fixtures, rotas ou schema da API: rode `pnpm --filter api contracts:generate && pnpm sync:shared` e commite o resultado. O CI falha se houver diff.

## Convenções de dados (SQLite e Postgres)

- PK `id` UUIDv7, gerado no cliente.
- Toda tabela de dado do usuário tem `athlete_id`, `created_at`, `updated_at`, `deleted_at` (exclusão lógica). A tabela `athlete` é a raiz, então o próprio `id` é o atleta.
- Datas em UTC: `timestamptz` no Postgres, texto ISO 8601 no SQLite.
- Pesos em kg com decimal (62.5). Carga somada e dinheiro em `numeric` no Postgres, nunca float.
- Valores derivados (XP total, nível, patente, atributos, sequência) não são colunas: são calculados a partir dos registros.
- O schema local espelha o do Postgres: mesmos nomes de tabela e coluna (snake_case, singular). O teste `SchemaParityTests` compara o SQLite com `packages/contracts/db-schema.json`, exportado do Drizzle.
- Enum do Postgres vira TEXT com CHECK no SQLite; `jsonb` vira JSON em TEXT; `date` vira "YYYY-MM-DD".
- Em consultas GRDB, compare ids com `uuid.sql` (texto minúsculo); um `UUID` cru vira blob e não casa.

## Progressão

- Regras em `packages/progression/progression.json` (valores) com implementação em TS (`packages/progression/src`) e em Swift (`HTSDomain`).
- Lógica de progressão muda no TS e no Swift juntos, com fixture novo em `packages/fixtures/`. Os dois lados rodam os mesmos casos; divergência quebra o CI.

## Regras visuais essenciais

- Tokens como única fonte: nunca escreva cor, tamanho ou espaçamento literal; use `Color.hts.*`, `Font.hts(...)`, `HTSSpacing`, `HTSNotch`. Mudou o visual? Mude tokens.json e rode `pnpm sync:shared`.
- Vermelho (`blood`) só na ação principal, em alerta e em recorde. Texto vermelho é `redText`.
- Sem sombra, sem gradiente, sem glow. Cantos retos; o canto é o entalhe (`NotchShape`).
- Estêncil só no "HTS" do topo (`brand-app`). Números com `.monospacedDigit()`.
- Voz: sem emoji, sem exclamação, botões começam por verbo ("Iniciar treino").

## Fluxo de tickets (GitHub Issues)

- Backlog em GitHub Issues de `leotheodoro/hts`, lido e escrito com `gh`. Labels: `area:*`, `type:*`, `priority:*`, `blocked`.
- Antes de implementar: `gh issue view <N> --comments`. Se os critérios de aceite não estiverem claros, pergunte antes de codar.
- Um ticket por branch: `<N>-<slug-curto>` a partir de `main` (ex.: `12-active-session`).
- PR com `Closes #<N>` no corpo. Decisões tomadas durante o trabalho viram comentário na issue (ou ADR, se forem duradouras).
- O ticket só está pronto com o CI verde no PR. Novo trabalho descoberto vira issue nova, não escopo extra.
- Merge: o Claude faz squash merge quando o CI está verde e todos os critérios de aceite estão marcados. PR que depende de teste do Leo (ex.: no iPhone) fica em rascunho até o ok dele.
- Quadro: https://github.com/users/leotheodoro/projects/1 (Todo, In Progress, Done). Mova o card ao começar e ao terminar.

## Commits

- Gitmoji: `<emoji> <mensagem curta no imperativo>` em inglês. Ex.: `✨ Add health endpoint`, `🐛 Fix rest timer reset`.
- Commits pequenos, um por etapa.
- Sem linha de co-autor de IA.
