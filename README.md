# Hard To Submit (HTS)

App iOS para registrar treinos de preparação física para jiu-jitsu, com camada de progressão (XP, nível, patente, atributos), e a API que guarda os dados em Postgres.

Visão de produto, glossário e regras do repo: [CLAUDE.md](CLAUDE.md). Decisões: [docs/decisions](docs/decisions).

## Setup do zero em um Mac novo

1. Instale o Xcode 26 ou mais novo pela App Store. Abra uma vez e aceite a licença.
2. Instale o runtime do simulador iOS:
   ```sh
   xcodebuild -downloadPlatform iOS
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
| `pnpm --filter api openapi:generate` | Escreve `packages/contracts/openapi.json` |
| `make ios-generate` | Gera `apps/ios/HTS.xcodeproj` com XcodeGen |
| `make ios-test` | `swift test` no HTSKit e `xcodebuild test` do app no simulador |
| `make ios-build` | Build do app para o simulador |
| `make ios-format` | `swift format` em todo o Swift |

## Arquivos compartilhados

`packages/` é a fonte. O HTSKit recebe cópias versionadas, geradas por `pnpm sync:shared`. Não edite as cópias: o CI roda o sync e falha se houver diff.
