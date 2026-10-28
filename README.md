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
6. Suba o Postgres e a API:
   ```sh
   cp apps/api/.env.example apps/api/.env
   docker compose up -d
   pnpm --filter api db:migrate
   pnpm dev
   curl http://localhost:8787/health
   ```
7. Gere o projeto iOS, rode os testes e abra no Xcode:
   ```sh
   make ios-generate
   make ios-test
   open apps/ios/HTS.xcodeproj
   ```
   Rode o esquema `HTS` no simulador iPhone 17 Pro Max. A aba Perfil mostra o Diagnóstico (só em Debug), com o atleta local e o `GET /health` da API em `localhost:8787`.

## Rodar no iPhone

Funciona com um Apple ID gratuito (Personal Team). Nesse caso o app expira em 7 dias; rode de novo para renovar.

1. No Xcode, em **Settings > Accounts**, adicione o Apple ID. Selecione o time, clique em **Manage Certificates… > + > Apple Development**.
2. Crie o arquivo local (fora do git) e preencha o Team ID:
   ```sh
   cp apps/ios/Local.xcconfig.example apps/ios/Local.xcconfig
   make ios-team-id      # mostra o Team ID do certificado
   make ios-mac-host     # valor para HTS_DEVICE_API_BASE_URL
   ```
   Se o Personal Team recusar o bundle id `com.hardtosubmit.app`, descomente `HTS_BUNDLE_ID` com um sufixo seu.
3. No iPhone: ligue o **Modo de Desenvolvedor** (Ajustes > Privacidade e Segurança), conecte por cabo e confie no Mac.
4. Instale e abra:
   ```sh
   make ios-device                          # ou DEVICE="Nome do iPhone" make ios-device
   ```
   Ou rode pelo Xcode escolhendo o iPhone como destino. Na primeira abertura, o iOS pede para confiar no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.
5. Para o Diagnóstico ver a API, deixe `pnpm dev` rodando no Mac, com o iPhone na mesma Wi-Fi, e aceite o pedido de acesso à rede local.

O simulador continua usando `localhost`; só builds para o aparelho usam `HTS_DEVICE_API_BASE_URL`. Configurações de build ficam em `apps/ios/Config/*.xcconfig`.

## Notas

- O Postgres do docker-compose escuta na porta **5442** do host, para não conflitar com outro Postgres local. Os testes da API usam o banco `hts_test`, criado pelo script em `docker/postgres/init`.
- O app desliga o Liquid Glass (`UIDesignRequiresCompatibility` no `project.yml`). A barra de vidro ignora as cores das abas e acrescenta blur. A Apple vai remover essa chave em uma versão futura; até lá, a barra fica opaca e segue os tokens.
- `make ios-*` escolhe o simulador pelo nome, através de `scripts/ios-simulator-id.sh`. Para usar outro aparelho: `make ios-test SIMULATOR="iPhone 17 Pro"`.
- Para abrir o app direto numa aba, em Debug: argumento de lançamento `-HTSInitialTab profile` (`status`, `arcs`, `journal`, `profile`).
- Fontes: TTF estáticos do Google Fonts (OFL), com as licenças em `HTSDesign/Resources/Fonts/Licenses`. O Noto Serif JP 900 completo tem 8 MB; fazer um subset dele é um ticket separado.

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
