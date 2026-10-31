# Integração com o Garmin: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atividades do Garmin entram no histórico do atleta, dão XP e atributos pelo tempo e pelo tipo, aparecem no Diário com o selo do Garmin, e o Perfil ganha a página Integrações. Tudo funciona agora com atividades de exemplo; o login e o push reais do Garmin entram quando o acesso for aprovado.

**Architecture:**
- **Regras** em `progression.json`, com TS e Swift implementando e fixtures compartilhados: XP e atributos por atividade e o vínculo por horário.
- **Dados:** a atividade é uma linha sincronizada (`imported_activity`) que nasce no servidor. Os tokens ficam numa tabela só do servidor (`integration_connection`).
- **App:** XP, atributos e vínculo são derivados na hora, como o resto da progressão.
- **Endpoint de push:** já recebe o formato de exemplo. O parser fica isolado para ser ajustado à documentação oficial.

**Tech Stack:** TypeScript (Hono, Drizzle, Vitest), Swift 6 (SwiftUI, GRDB, Swift Testing), fixtures JSON compartilhados.

**Spec:** `docs/superpowers/specs/2026-10-31-garmin-integration-design.md`

## Global Constraints

- **Valores:** XP = minutos que contam × 5, contando no máximo 60 minutos por atividade. XP de atributo = 10 a cada 4 minutos que contam (`round(minutos × 10 / 4)`), para cada atributo do tipo. Os três valores ficam em `progression.json`.
- **Extra:** atividade dá XP, nível, patente e atributos. Fica fora da meta semanal, da sequência e dos títulos.
- **Vínculo:** uma atividade está vinculada quando o tempo dela que cruza um treino concluído do HTS (`started_at` a `finished_at`) passa de **mais da metade** da duração dela. Atividade vinculada não dá XP, não vira entrada no Diário e aparece dentro do treino (FC média e calorias). O vínculo é derivado, nunca guardado.
- **Tipos → atributos:**
  - corrida, bike, remo, elíptico, caminhada → `conditioning`;
  - natação → `conditioning` + `strength`;
  - HIIT e cardio → `conditioning` + `power`;
  - yoga, pilates e alongamento → `mobility`;
  - musculação → `strength`;
  - luta e artes marciais → `conditioning` + `core`;
  - desconhecido → nenhum atributo.
- **Convenções de dados:** UUIDv7, `athlete_id`, `created_at`, `updated_at`, `deleted_at`, nomes iguais no SQLite e no Postgres, nada derivado em coluna. A única exceção (o id nasce no servidor) vira o ADR 0033.
- **Tokens do Garmin:** só no servidor, nunca no aparelho nem em arquivo versionado.
- **Marca:** o azul do Garmin é a única exceção às cores do HTS, só no botão Conectar e no selo, e entra como token. Até chegar o kit oficial, o selo é a palavra GARMIN em texto, sem desenho de logo.
- **Interface:**
  - textos em pt-BR, no String Catalog;
  - tokens como única fonte (`Color.hts.*`, `HTSSpacing`, `HTSNotch`);
  - sem emoji nem exclamação;
  - botões começam pelo verbo.
- **Fluxo do repo:**
  - um ticket por branch, PR com `Closes #N`, squash merge com o CI verde e `make ios-test SIMULATOR="HTS Dev"` local;
  - depois de mudar o schema, as rotas ou `progression.json`: rodar `pnpm --filter api contracts:generate && pnpm sync:shared` e commitar.

## Review Focus

1. **Atividade que cruza o treino só em parte.** Ex.: uma corrida de 30 min que termina 10 min depois do início do treino não é vinculada e conta inteira. Teste: fixture `activity-link` "less than half overlap is not linked".
2. **Mesma atividade chegando duas vezes no push**, ou chegando de novo com outra duração. Deve atualizar a linha existente, nunca duplicar. Teste: `garmin.test.ts` "a repeated activity updates the same row".
3. **Push de um usuário Garmin sem conexão**, ou depois de desconectar. Responde 200 (para o Garmin não ficar reenviando) e não grava nada. Teste: `garmin.test.ts` "ignores activities of an unknown Garmin user".
4. **Treino do HTS apagado depois do vínculo.** A atividade volta a contar sozinha no XP e no Diário. Teste: `ProgressServiceActivityTests.unlinksWhenTheSessionIsDeleted`.
5. **Atividade de duração zero ou acima de 60 min.** Zero dá 0 XP, sem divisão por zero no vínculo. Acima de 60 min conta como 60. Testes: fixture `activity-xp` "over the cap counts 60 minutes" e "zero duration gives nothing"; fixture `activity-link` "zero duration is never linked".

---

### Task 1: Regras de atividade em `progression.json`, TS e Swift (#A)

**Files:**
- Modify: `packages/progression/progression.json`, `packages/progression/src/index.ts`, `packages/progression/test/fixtures.test.ts`
- Create: `packages/fixtures/activity-xp.json`, `packages/fixtures/activity-link.json`
- Modify: `packages/fixtures/progress-history.json`, `packages/fixtures/attribute-levels.json` (novos casos com `activities`)
- Create: `apps/ios/HTSKit/Sources/HTSDomain/Activity.swift`
- Modify: `apps/ios/HTSKit/Sources/HTSDomain/Progression.swift` (regras), `ProgressHistory.swift`, `AttributeLevels.swift`, `apps/ios/HTSKit/Tests/HTSDomainTests/SharedFixtureTests.swift`

**Interfaces:**
- Produces (TS):
  - `rules.activity: { xpPerMinute: number; maxMinutes: number; attributeXp: number; minutesPerAttributeXp: number; attributes: Record<string, Attribute[]> }`.
  - `activityXp(input: { activityType: string; durationSeconds: number }): { minutes: number; xp: number; attributeXp: number; attributes: Attribute[] }`.
  - `isActivityLinked(activity: { startedAt: string; durationSeconds: number }, sessions: { startedAt: string; finishedAt: string }[]): boolean`.
  - `progressHistory(sessions, r?, activities?: HistoryActivity[])`, com `HistoryActivity = { activityType: string; durationSeconds: number; linked: boolean }`. `totalXp` soma o XP das atividades não vinculadas.
  - `attributeLevels(sets, r?, activities?: { attributes: Attribute[]; attributeXp: number }[])`.
- Produces (Swift, em `Progression`), espelhando o TS:
  - `activityXP(activityType: String, durationSeconds: Int) -> ActivityXP` (com `minutes`, `xp`, `attributeXP`, `attributes`).
  - `isActivityLinked(startedAt: Date, durationSeconds: Int, sessions: [(startedAt: Date, finishedAt: Date)]) -> Bool`.
  - `history(_ sessions: [HistorySession], activities: [HistoryActivity] = [])`.
  - `attributeLevels(_ sets: [AttributeSet], activities: [ActivityAttributeXP] = [])`.

- [ ] **Step 1: Escrever os fixtures** (e incluí-los no harness TS e no Swift)

`activity-xp.json` (`function: "activityXp"`), casos e `expected`:
- "a 40 min run feeds conditioning": `{RUNNING, 2400}` → `{minutes:40, xp:200, attributeXp:100, attributes:["conditioning"]}`.
- "swimming feeds conditioning and strength": `{LAP_SWIMMING, 2400}` → `{minutes:40, xp:200, attributeXp:100, attributes:["conditioning","strength"]}`.
- "over the cap counts 60 minutes": `{RUNNING, 5400}` → `{minutes:60, xp:300, attributeXp:150, attributes:["conditioning"]}`.
- "partial minutes are dropped": `{YOGA, 659}` → `{minutes:10, xp:50, attributeXp:25, attributes:["mobility"]}`.
- "one minute rounds 2.5 up": `{RUNNING, 60}` → `{minutes:1, xp:5, attributeXp:3, attributes:["conditioning"]}`.
- "unknown type gives XP without attributes": `{GOLF, 1200}` → `{minutes:20, xp:100, attributeXp:50, attributes:[]}`.
- "zero duration gives nothing": `{RUNNING, 0}` → `{minutes:0, xp:0, attributeXp:0, attributes:["conditioning"]}`.

`activity-link.json` (`function: "isActivityLinked"`). Treino de 10:00 a 11:00 UTC de 2026-11-02 em todos os casos:
- "inside the workout is linked": início 10:10, 1800 s → `true`.
- "more than half overlap is linked": início 09:40, 3000 s (30 de 50 min dentro) → `true`.
- "exactly half is not linked": início 09:40, 2400 s (20 de 40 min) → `false`.
- "less than half overlap is not linked": início 09:40, 1800 s (10 de 30 min) → `false`.
- "no workouts": sessões `[]` → `false`.
- "zero duration is never linked": início 10:10, 0 s → `false`.

`progress-history.json`, caso novo "unlinked activities add XP, linked ones do not": uma sessão com 1 série concluída de 10 reps a `"50"` kg, unidade reps, mais duas atividades `RUNNING` de 2400 s, uma `linked:false` e outra `linked:true`. Esperado: `sessions: [{completedSets:1, volumeKg:"500", records:[], xp:51}]` (10 + 40 + 1 de volume), `totalXp: 251`, `level: 2`, `rank: "E"`.

`attribute-levels.json`, caso novo "activities add their attribute XP": um set `strength` concluído mais a atividade `{attributes:["conditioning"], attributeXp:100}` → `strength {xp:10, level:1}`, `conditioning {xp:100, level:1}`, os outros `{xp:0, level:1}`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `pnpm --filter @hts/progression test` e `make ios-kit-test`, da raiz.
Expected: FAIL (`activityXp` não existe; Swift não compila).

- [ ] **Step 3: Implementar**

- Em `progression.json`, adicionar `"activity": { "xpPerMinute": 5, "maxMinutes": 60, "attributeXp": 10, "minutesPerAttributeXp": 4, "attributes": { ... } }`. As chaves de tipo vêm do Garmin em CAIXA ALTA:
  - `RUNNING`, `TREADMILL_RUNNING`, `TRAIL_RUNNING`, `CYCLING`, `INDOOR_CYCLING`, `ROWING`, `INDOOR_ROWING`, `ELLIPTICAL`, `WALKING` → `conditioning`;
  - `LAP_SWIMMING`, `OPEN_WATER_SWIMMING` → `conditioning`, `strength`;
  - `HIIT`, `INDOOR_CARDIO` → `conditioning`, `power`;
  - `YOGA`, `PILATES`, `STRETCHING` → `mobility`;
  - `STRENGTH_TRAINING` → `strength`;
  - `BOXING`, `MIXED_MARTIAL_ARTS` → `conditioning`, `core`.
- A conta dos minutos é `minutes = min(floor(durationSeconds / 60), maxMinutes)`.
- O XP de atributo é `round(minutes × attributeXp / minutesPerAttributeXp)`, arredondando metade para cima. É o `Math.round` no TS e `.rounded()` (`.toNearestOrAwayFromZero`) no Swift.
- O vínculo exige `durationSeconds > 0` e soma a interseção com cada sessão (as sessões não se cruzam). Vincula quando `2 × overlap > duration`.
- Os novos parâmetros têm default vazio, para os fixtures antigos passarem sem mudança.

- [ ] **Step 4: Rodar e ver passar**

Run: `pnpm --filter @hts/progression test`, depois `pnpm sync:shared && make ios-kit-test`.
Expected: PASS nos dois lados, com os casos novos.

- [ ] **Step 5: Commit** — `✨ Add the activity XP and link rules`

### Task 2: Tabelas `imported_activity` e `integration_connection`, mais a sync (#B)

**Files:**
- Modify: `apps/api/src/db/schema.ts`; Create: `apps/api/drizzle/0009_*.sql` (gerada)
- Modify: `apps/api/src/sync.ts` (TABLES), `apps/ios/HTSKit/Sources/HTSPersistence/AppDatabase.swift` (migration `v11_imported_activity`), `SyncService.swift` (tables)
- Create: `apps/ios/HTSKit/Sources/HTSPersistence/ImportedActivity.swift` (record GRDB)
- Create: `docs/decisions/0033-imported-activities.md`
- Test: `apps/api/test/sync.test.ts`, `apps/ios/HTSKit/Tests/HTSPersistenceTests/SyncServiceTests.swift`, `SchemaParityTests` (já existente)

**Interfaces:**
- Produces:
  - **Postgres `imported_activity`:** `owned()` + `source text not null` + `external_id text not null` + `activity_type text not null` + `name text` + `started_at timestamptz not null` + `duration_seconds integer not null` + `distance_meters numeric(9,2)` + `average_heart_rate smallint` + `calories integer` + `timestamps`. `uniqueIndex(source, external_id)` e `index(athlete_id, started_at)`.
  - **SQLite:** a mesma tabela, `numeric` como TEXT decimal (como `meters`).
  - **Postgres `integration_connection`:** só no servidor, em `SERVER_ONLY_TABLES`. Colunas: `id uuid pk`, `account_id → account.id not null`, `provider text not null`, `external_user_id text not null`, `access_token text`, `refresh_token text`, `token_expires_at timestamptz`, `connected_at timestamptz not null default now()`, `last_activity_at timestamptz`. `uniqueIndex(provider, external_user_id)` e `uniqueIndex(account_id, provider)`.
  - **Swift:** `public struct ImportedActivity: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable`, com propriedades camelCase (`source`, `externalId`, `activityType`, `name`, `startedAt: Date`, `durationSeconds: Int`, `distanceMeters: Decimal?`, `averageHeartRate: Int?`, `calories: Int?`, `deletedAt`).

- [ ] **Step 1: Testes**
  - **API**, em `sync.test.ts`, "pulls imported activities and refuses them for another athlete": inserir uma atividade do Leo direto no banco. Ela vem no pull com `distance_meters "8200.00"`, e um push dela com o token de outro atleta dá 403.
  - **Swift**, em `SyncServiceTests.importedActivitiesArriveByPull`: o fake server tem uma linha de `imported_activity`; depois do sync, `ImportedActivity.fetchAll` traz 1 linha com `durationSeconds 2400`.
- [ ] **Step 2: Rodar e ver falhar.** Comando: `pnpm --filter api test` e `make ios-kit-test`. Esperado: FAIL, tabela inexistente.
- [ ] **Step 3: Implementar**
  - Schema e `pnpm --filter api db:generate`.
  - `imported_activity` logo depois de `athlete` em `TABLES`, nos dois lados.
  - Migration SQLite `v11_imported_activity`.
  - `pnpm --filter api contracts:generate && pnpm sync:shared`.
  - ADR 0033: o id nasce no servidor porque a linha nasce lá; o app só lê. Registrar também que XP, atributos e vínculo são derivados.
- [ ] **Step 4: Rodar e ver passar.** Comando: `pnpm --filter api test && pnpm typecheck`, depois `make ios-test SIMULATOR="HTS Dev"`. Esperado: PASS, com `SchemaParityTests` verde.
- [ ] **Step 5: Commit.** `🗃️ Add imported activities and integration connections`

### Task 3: API: importar o push do Garmin e o status das integrações (#C)

**Files:**
- Create: `apps/api/src/garmin/payload.ts` (parser isolado do formato do Garmin), `apps/api/src/garmin/import.ts`, `apps/api/src/routes/integrations.ts`
- Modify: `apps/api/src/app.ts`, `apps/api/src/env.ts` (`GARMIN_PUSH_SECRET` opcional), `.env.example`, `render.yaml`
- Create: `apps/api/test/fixtures/garmin-activities.json` (payload de exemplo); Test: `apps/api/test/garmin.test.ts`, `apps/api/test/integrations.test.ts`

**Interfaces:**
- Consumes: as tabelas da Task 2.
- Produces:
  - `parseGarminActivities(body: unknown): GarminActivity[]`. O exemplo segue o formato documentado publicamente para o push de atividades: `{ activities: [{ userId, summaryId, activityId, activityType, activityName, startTimeInSeconds, durationInSeconds, distanceInMeters?, averageHeartRateInBeatsPerMinute?, activeKilocalories? }] }`. Um item com `deleted: true` vira exclusão; ajustar à documentação oficial na Task 8.
  - `importGarminActivities(db, activities): Promise<{ imported: number; ignored: number }>`. Acha a conexão por `external_user_id` e o atleta pela conta. Faz upsert por `(source='garmin', external_id=summaryId)`, gerando um UUIDv7 novo só na inserção, com `updated_at = now`. Também atualiza `last_activity_at`.
  - **Rotas:**
    - `POST /integrations/garmin/push/:secret`, fora de `/v1` e sem sessão: 404 quando o secret não bate ou não está configurado; 200 `{imported, ignored}`.
    - `GET /v1/integrations`: `{ integrations: [{ provider: "garmin", connected: boolean, connectedAt: string|null, lastActivityAt: string|null }] }`.
    - `POST /v1/integrations/garmin/connect`: até a Task 8, responde 503 `{error:"garmin_unavailable"}`.
    - `DELETE /v1/integrations/garmin`: apaga a conexão do atleta da sessão e responde 204. As atividades ficam.
- [ ] **Step 1: Testes** (`garmin.test.ts`):
  - "imports an activity of a connected user": confere tipo, duração, distância, FC e calorias.
  - "a repeated activity updates the same row": manda o mesmo `summaryId` com outra duração e confere 1 linha com a duração nova.
  - "ignores activities of an unknown Garmin user": 200 com `ignored: 1` e nada gravado.
  - "a deletion soft-deletes": confere `deleted_at` preenchido.
  - "wrong secret answers 404".

  Em `integrations.test.ts`:
  - "status shows connected and the last activity";
  - "disconnect removes the connection and keeps the activities";
  - "connect answers 503 until Garmin is configured";
  - "routes need a session" (401).
- [ ] **Step 2: Rodar e ver falhar.** Comando: `pnpm --filter api test`.
- [ ] **Step 3: Implementar.** Depois rodar `pnpm --filter api contracts:generate && pnpm sync:shared`. No iOS, adicionar ao `RemoteAPI`/`APIClient` e ao `FakeRemote`:
  - `integrations() async throws -> [IntegrationStatus]`;
  - `connectGarmin() async throws -> URL`, que lança `APIError.garminUnavailable` no 503;
  - `disconnectGarmin() async throws`.
- [ ] **Step 4: Rodar e ver passar.** Comando: `pnpm --filter api test && pnpm typecheck && pnpm lint`, depois `make ios-test SIMULATOR="HTS Dev"`.
- [ ] **Step 5: Commit.** `✨ Import Garmin activity pushes and expose the integration status`

### Task 4: Progresso com atividades no app (#D)

**Files:**
- Create: `apps/ios/HTSKit/Sources/HTSPersistence/ActivityRepository.swift`
- Modify: `apps/ios/HTSKit/Sources/HTSPersistence/ProgressService.swift`
- Test: `apps/ios/HTSKit/Tests/HTSPersistenceTests/ProgressServiceActivityTests.swift`

**Interfaces:**
- Consumes: `ImportedActivity` (Task 2); `Progression.activityXP`, `isActivityLinked`, `history(_:activities:)`, `attributeLevels(_:activities:)` (Task 1).
- Produces:
  - `ActivityRepository(database).activities(athleteId:) async throws -> [ImportedActivity]` (não apagadas, por `started_at`).
  - `ProgressService.ActivityEntry { activity: ImportedActivity; xp: ActivityXP; linkedSessionId: UUID? }`.
  - `ProgressService.activities(athleteId:) async throws -> [ActivityEntry]`.
  - `history(athleteId:)` e `attributeLevels(athleteId:)` passam a incluir as atividades.
  - Em `completion(sessionId:)`, `before` e `after` contam as atividades que começaram antes do `started_at` do treino.
- [ ] **Step 1: Testes**
  - `historyCountsAnUnlinkedRun`: treino concluído mais uma corrida de 40 min no dia seguinte. O `totalXp` cresce 200 e o GÁS ganha 100.
  - `aRunInsideTheWorkoutIsLinked`: `linkedSessionId` igual ao treino, e o `totalXp` não muda.
  - `unlinksWhenTheSessionIsDeleted`: depois de `SessionRepository.delete`, o vínculo vira `nil` e a atividade volta a contar.
  - `deletedActivitiesDoNotCount`.
- [ ] **Step 2: Rodar e ver falhar.** Comando: `make ios-kit-test`.
- [ ] **Step 3: Implementar.** Só treinos concluídos com `finished_at` entram no vínculo.
- [ ] **Step 4: Rodar e ver passar.** Comando: `make ios-test SIMULATOR="HTS Dev"`.
- [ ] **Step 5: Commit.** `✨ Count Garmin activities in the progress`

### Task 5: Diário com o selo do Garmin (#E)

**Files:**
- Modify: `packages/design-tokens/tokens.json`: novos tokens `garmin`, `#007CC3`, uso "Só no botão Conectar Garmin e no selo GARMIN", e `on-garmin`, `#FFFFFF`. Depois rodar `pnpm sync:shared`.
- Create: `apps/ios/HTS/Components/GarminBadge.swift`, `apps/ios/HTS/Screens/Journal/ActivityDetailSheet.swift`
- Modify: `apps/ios/HTS/Screens/Journal/JournalModel.swift`, `JournalScreen.swift`, `SessionDetailSheet.swift`
- Test: `apps/ios/HTSTests/JournalModelTests.swift`

**Interfaces:**
- Consumes: `ProgressService.activities(athleteId:)` (Task 4).
- Produces:
  - `JournalModel.Item`, que é `.session(Entry)` ou `.activity(ProgressService.ActivityEntry)`, em ordem de data, do mais novo para o mais antigo. `items: [Item]`.
  - `linkedActivities: [UUID: ImportedActivity]`, com a chave sendo o id do treino.
  - Os totais (`entries.count`, `totalSets`, `totalVolume`) continuam só com os treinos.
- [ ] **Step 1: Testes** em `JournalModelTests`:
  - `activitiesInterleaveWithSessionsByDate`;
  - `linkedActivityIsNotAnItem`, que também confere a atividade em `linkedActivities[sessionId]`;
  - `totalsCountOnlySessions`.
- [ ] **Step 2: Rodar e ver falhar.** Comando: `make ios-test SIMULATOR="HTS Dev"`.
- [ ] **Step 3: Implementar.**
  - Card da atividade igual ao modelo 3 do spec: data, "+N XP", nome do tipo em pt-BR ("Corrida", "Natação", "Bike", "Yoga", "Musculação", "Luta" e "Atividade" para os desconhecidos), o selo, a linha "8,2 km · 40 min · 4:53 /km · FC 152" (cada parte só se existir) e os códigos dos atributos.
  - `ActivityDetailSheet`, aberto pelo toque no card, com tipo, data e hora, duração, distância, pace, FC média, calorias, XP e atributos.
  - O `SessionDetailSheet` mostra "FC média" e "Calorias" com o selo quando há atividade vinculada.
  - Os nomes dos tipos ficam num `extension` em `DomainLabels.swift`.
- [ ] **Step 4: Rodar e ver passar.** Comando: `make ios-test SIMULATOR="HTS Dev" && make ios-lint`. Tirar captura do Diário com o modo de demonstração da Task 7.
- [ ] **Step 5: Commit.** `✨ Show Garmin activities in the journal with their badge`

### Task 6: Página Integrações no Perfil (#F)

**Files:**
- Create: `apps/ios/HTS/Screens/Profile/IntegrationsScreen.swift`
- Modify: `apps/ios/HTS/Screens/ProfileScreen.swift` (linha "Integrações" depois de "Atributos"), `Route` (`.integrations`), `apps/ios/HTS/App/AppModel.swift`
- Test: `apps/ios/HTSTests/AuthTests.swift`, ou um arquivo novo `IntegrationsTests.swift`

**Interfaces:**
- Consumes: `RemoteAPI.integrations/connectGarmin/disconnectGarmin` (Task 3), `ActivityRepository` (contagem).
- Produces:
  - `AppModel.garminStatus: IntegrationStatus?`.
  - `AppModel.loadIntegrations() async`.
  - `AppModel.connectGarmin() async -> IntegrationError?`, que devolve `.unavailable` no 503 e `.offline` sem rede. Quando recebe uma URL, abre `ASWebAuthenticationSession`; isso vale a partir da Task 8.
  - `AppModel.disconnectGarmin() async -> IntegrationError?`.
- [ ] **Step 1: Testes**
  - `connectReportsUnavailableBeforeApproval`;
  - `disconnectClearsTheStatus`;
  - `statusComesFromTheAPI`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar a tela dos modelos 1 e 2.**
  - **Card do Garmin** (`NotchCard`) com a palavra GARMIN e uma linha explicando: "Corridas e outros treinos do relógio entram no Diário e dão XP. Não contam para a meta da semana."
  - **Desconectado:** botão "Conectar Garmin" em `garmin`/`onGarmin`.
  - **Conectado:**
    - status "Conectado" com a data de `connectedAt`, no lugar da conta, porque a API do Garmin não dá o nome dela;
    - "Último treino recebido", com o tipo e quando, vindo do `ActivityRepository`;
    - "Treinos importados", a contagem;
    - botão fantasma "Desconectar", com confirmação.
  - **Mensagens:**
    - indisponível: "A conexão com o Garmin ainda não foi liberada.";
    - sem rede: o padrão do app.
- [ ] **Step 4: Rodar e ver passar.** Depois tirar captura das duas telas.
- [ ] **Step 5: Commit.** `✨ Add the Integrations page with the Garmin card`

### Task 7: Modo de demonstração (#G)

**Files:** Modify: `apps/ios/HTS/App/DemoData.swift`. Test: `apps/ios/HTSTests/HomeModelTests.swift`, ou um teste novo do `DemoData`.

**Interfaces:**
- Produces: `-HTSDemoActivities YES`, que liga também a sessão local e semeia três atividades no banco local, só em DEBUG:
  - uma corrida de 40 min ontem às 07:00;
  - um yoga de 25 min há 3 dias;
  - uma musculação gravada no relógio dentro do treino de demonstração, para mostrar o vínculo.
- [ ] **Step 1: Teste.** `demoActivitiesSeedOnce`: chamado duas vezes, continuam 3 linhas.
- [ ] **Step 2: Implementar.**
- [ ] **Step 3: Rodar e ver passar.** Depois tirar a captura do Diário e do Perfil > Integrações.
- [ ] **Step 4: Commit.** `🔧 Seed demo Garmin activities in DEBUG`

### Task 8: Login e push reais do Garmin (#H, bloqueado até a aprovação)

Abrir como issue com o label `blocked`. Só começa quando o Garmin aprovar e liberar a documentação.

- **OAuth do Garmin** (`POST /v1/integrations/garmin/connect` devolve a URL de autorização), com callback na API, troca do código por tokens e gravação em `integration_connection`.
- **App:** abre a URL com `ASWebAuthenticationSession` e volta para Integrações.
- **Push:**
  - ajustar `parseGarminActivities` aos nomes oficiais e ao aviso de exclusão;
  - conferir os ids de tipo contra a tabela da Task 1;
  - cadastrar a URL de push no portal do Garmin.
- **Desconectar:** revogar no Garmin, se a API permitir.
- **Marca:** trocar o selo de texto pelo logo do kit oficial, seguindo as regras do Garmin.
- **Testes:** com os payloads reais da documentação.
