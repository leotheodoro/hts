# Hard To Submit (HTS)

App iOS para registrar treinos de preparação física para jiu-jitsu, com camada de progressão (XP, nível, patente, atributos), e a API que guarda os dados em Postgres.

Visão de produto, glossário e regras do repo: [CLAUDE.md](CLAUDE.md). Decisões: [docs/decisions](docs/decisions).

## Setup do zero em um Mac novo

1. Instale o Xcode 26 ou mais novo pela App Store. Abra uma vez e aceite a licença.
2. Instale o runtime do simulador iOS 26. O iPhone 17 Pro Max não roda nos runtimes iOS 27.x:
   ```sh
   xcodebuild -downloadPlatform iOS -buildVersion 26.5
   ```
3. Instale o Homebrew (https://brew.sh) e as ferramentas:
   ```sh
   brew install xcodegen nvm
   brew install --cask docker   # ou OrbStack
   ```
4. Instale o Node da versão em `.nvmrc` (24 LTS) e ative o pnpm via corepack:
   ```sh
   nvm install
   nvm use
   corepack enable
   ```
5. Instale as dependências e confira:
   ```sh
   pnpm install
   pnpm lint
   pnpm test        # precisa do Postgres do passo 6 para os testes da API
   ```
6. Suba o Postgres e a API, e crie a sua conta. Não há cadastro no app: a conta vem do seed (docs/decisions/0031). No `.env`, preencha `SEED_NAME`, `SEED_USERNAME`, `SEED_EMAIL` e `SEED_PASSWORD`:
   ```sh
   cp apps/api/.env.example apps/api/.env
   docker compose up -d
   pnpm --filter api db:migrate
   pnpm --filter api db:seed     # cria ou atualiza a conta; importa o plano, se houver (veja "Plano do treinador")
   pnpm dev
   curl http://localhost:8787/health
   ```
7. Gere o projeto iOS, rode os testes e abra no Xcode:
   ```sh
   make ios-generate
   make ios-test
   open apps/ios/HTS.xcodeproj
   ```
   Rode o esquema `HTS` no simulador iPhone 17 Pro Max e entre com o usuário (ou e-mail) e a senha do seed. O simulador fala com a API em `localhost:8787`.

## Rodar no iPhone

Funciona com um Apple ID gratuito (Personal Team). Nesse caso o app expira em 7 dias; rode de novo para renovar.

1. No Xcode, em **Settings > Accounts**, adicione o Apple ID. Selecione o time, clique em **Manage Certificates… > + > Apple Development**.
2. Crie o arquivo local (fora do git) e preencha o Team ID:
   ```sh
   cp apps/ios/Local.xcconfig.example apps/ios/Local.xcconfig
   make ios-team-id      # mostra o Team ID do certificado
   make ios-mac-host     # só se quiser o iPhone no pnpm dev (HTS_DEVICE_API_BASE_URL)
   ```
   Se o Personal Team recusar o bundle id `com.hardtosubmit.app`, descomente `HTS_BUNDLE_ID` com um sufixo seu.
3. No iPhone: ligue o **Modo de Desenvolvedor** (Ajustes > Privacidade e Segurança), conecte por cabo e confie no Mac.
4. Instale e abra:
   ```sh
   make ios-device                          # ou DEVICE="Nome do iPhone" make ios-device
   ```
   Ou rode pelo Xcode escolhendo o iPhone como destino. Na primeira abertura, o iOS pede para confiar no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.
5. O iPhone sincroniza com a API de produção (Render + Neon, `https://api.hardtosubmit.com`, um CNAME para `hts-api-nrrk.onrender.com`). O acesso é pelo login da conta (docs/decisions/0031). Para testar contra o `pnpm dev`, defina `HTS_DEVICE_API_BASE_URL` com o endereço do Mac, deixe o iPhone na mesma Wi-Fi e aceite o pedido de acesso à rede local.

O simulador usa `localhost`; builds para o aparelho usam `HTS_DEVICE_API_BASE_URL` (por padrão, produção) e o Release usa sempre produção. Configurações de build ficam em `apps/ios/Config/*.xcconfig`.

## Plano do treinador (opcional)

Para a conta já ter as temporadas, os arcos e os treinos, copie `apps/api/seed.example` para `apps/api/seed` e edite o `starter-plan.json` (formato no README da pasta). A pasta fica fora do git: programas de preparador costumam ser licenciados e o repositório é público. `pnpm --filter api db:seed` importa só o que ainda não existe, pelo nome; o app recebe tudo pela sincronização depois do login. Para semear a produção, rode o seed com o `DATABASE_URL` do Neon na frente do comando.

## Deploy da API (Render + Neon)

O deploy é automático a cada push na `main` (`render.yaml`, ADR 0025). Para criar do zero:

1. **Neon**: em https://console.neon.tech crie um projeto (região AWS US East, perto do Render Virginia) e copie a connection string (`postgresql://…?sslmode=require`).
2. **Render**: em https://dashboard.render.com entre com o GitHub, vá em **Blueprints → New Blueprint Instance**, autorize o app do Render no repositório `hts` e escolha-o. O Render lê o `render.yaml` e pede as variáveis:
   - `DATABASE_URL` (passo 1).
   - Fotos de perfil (opcional): `AWS_ENDPOINT_URL_S3`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET`. Sem elas, o envio de foto responde 503.
   - Garmin (opcional): `GARMIN_CLIENT_ID`, `GARMIN_CLIENT_SECRET` (do app no portal do Garmin) e `GARMIN_PUSH_SECRET` (`openssl rand -hex 24`).

   Clique em **Apply**. As migrations rodam a cada deploy, antes de o servidor subir.
3. **Domínio**: no serviço do Render, em **Settings > Custom Domains**, adicione `api.hardtosubmit.com`; no DNS (Vercel), crie o CNAME `api` apontando para o endereço `onrender.com` do serviço. Quando `https://api.hardtosubmit.com/health` responder, o app já está apontado para ele (`HTS_PRODUCTION_API_BASE_URL` em `apps/ios/Config/Base.xcconfig`).
4. **Conta**: rode o seed contra o Neon (`DATABASE_URL='<url do Neon>' pnpm --filter api db:seed`, com Node 24) e entre no app com ela.
5. **Garmin** (opcional): no app do portal do Garmin, a OAuth redirect URL é `https://api.hardtosubmit.com/integrations/garmin/callback`. Em https://apis.garmin.com/tools/endpoints, ligue **Activities**, **Manually Updated Activities** e **Deregistrations** com a URL `https://api.hardtosubmit.com/integrations/garmin/push/<GARMIN_PUSH_SECRET>`.

## Site (Vercel)

`apps/web` é o site público (landing, política de privacidade e suporte), em Astro. O projeto `hardtosubmit-web` na Vercel usa Root Directory `apps/web` e publica sozinho a cada push na `main`, em https://hardtosubmit.com. Localmente: `pnpm --filter web dev`.

## Notas

- O Postgres do docker-compose escuta na porta **5442** do host, para não conflitar com outro Postgres local. Os testes da API usam o banco `hts_test`, criado pelo script em `docker/postgres/init`.
- O app desliga o Liquid Glass (`UIDesignRequiresCompatibility` no `project.yml`). A barra de vidro ignora as cores das abas e acrescenta blur. A Apple vai remover essa chave em uma versão futura; até lá, a barra fica opaca e segue os tokens.
- `make ios-*` escolhe o simulador pelo nome, através de `scripts/ios-simulator-id.sh`. Para usar outro aparelho: `make ios-test SIMULATOR="iPhone 17 Pro"`.
- Argumentos de lançamento em Debug: `-HTSInitialTab profile` abre numa aba (`home`, `arcs`, `journal`, `profile`); `-HTSSeedDemo YES` cria arcos e um treino de exemplo numa sessão local, sem login; `-HTSDemoActivities YES` acrescenta atividades do Garmin de exemplo.
- Fontes: TTF estáticos do Google Fonts (OFL), com as licenças em `HTSDesign/Resources/Fonts/Licenses`. O Noto Serif JP 900 é um subset (13 KB) só com os kanji de `packages/design-tokens/kanji.txt`; outro kanji cai na fonte do sistema. Para incluir mais, edite a lista e rode `scripts/subset-kanji-font.sh` (precisa de `pipx install fonttools`).

## Comandos

| Comando | O que faz |
| --- | --- |
| `pnpm dev` | API em modo watch na porta 8787 |
| `pnpm test` | Testes TS (Vitest). Os da API usam o Postgres do docker-compose |
| `pnpm lint` / `pnpm format` | Biome |
| `pnpm typecheck` | `tsc` em todos os pacotes |
| `pnpm sync:shared` | Gera `Tokens.swift` e copia progression.json, fixtures e openapi.json para o HTSKit |
| `pnpm --filter api db:generate` | Nova migration a partir do schema Drizzle |
| `pnpm --filter api db:migrate` | Aplica as migrations |
| `pnpm --filter api contracts:generate` | Escreve `packages/contracts/openapi.json` e `db-schema.json` |
| `make ios-generate` | Gera `apps/ios/HTS.xcodeproj` com XcodeGen |
| `make ios-test` | `swift test` no HTSKit e `xcodebuild test` do app no simulador |
| `make ios-build` | Build do app para o simulador |
| `make ios-format` | `swift format` em todo o Swift |

## Arquivos compartilhados

`packages/` é a fonte. O HTSKit recebe cópias versionadas, geradas por `pnpm sync:shared`. Não edite as cópias: o CI roda o sync e falha se houver diff.
