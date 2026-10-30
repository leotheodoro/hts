# Autenticação · design

Data: 2026-10-30 · Status: aprovado pelo Leo em 2026-10-30.

## Intenção

O HTS vai para a App Store aberta. Qualquer pessoa pode baixar, mas só entra quem tem conta. Por enquanto existe uma conta, a do Leo, criada direto no banco; não há cadastro no app.

Hoje o app fala com a API usando um token fixo embutido no binário (ADR 0024) e traz os programas do treinador dentro do bundle (`StarterPlan.json`). Numa versão pública, as duas coisas vazam: o token dá acesso à API e o arquivo leva conteúdo licenciado. Este trabalho substitui o token fixo por contas e tira os programas do app.

## Objetivos

- Tabela de conta com nome, username, senha (hash), e-mail e avatar_url.
- Tela de login que aceita username ou e-mail mais a senha. Nada do app aparece sem login.
- Uma vez logado, o iPhone continua logado até tocar em "Sair" ou apagar os dados do app.
- A API só atende quem está logado, e cada conta só lê e grava os próprios dados.
- Os programas do treinador saem do bundle e passam a viver no servidor, ligados à conta.
- Seed com a conta do Leo e os programas dele.
- Recomeço do zero: os dados de teste atuais somem, no Render e no iPhone.

## Fora do escopo

- Cadastro pelo app, "esqueci minha senha", troca de senha pelo app, troca de e-mail.
- Upload e exibição de avatar (a coluna existe e fica nula).
- Login social, biometria, 2FA.
- A conta de demonstração para o revisor da App Store (vem no ticket de publicação).

## Anti-objetivos (falha mesmo funcionando)

- A senha do Leo, o hash dela ou qualquer token em arquivo commitado. O repositório é público.
- Ser deslogado sozinho: por expiração, por reabrir o app, por ficar offline.
- Perder um treino feito offline por causa do login: o fluxo offline-first continua igual depois de entrar.
- Uma conta conseguir ler ou gravar dados de outro `athlete_id`.
- Conteúdo licenciado em qualquer arquivo do app publicado.

## Decisões do Leo

- Publicação na App Store aberta, acesso só com conta.
- Contas criadas pelo Claude, sem cadastro no app; uma conta por enquanto.
- Campos da conta: nome, username, senha, e-mail, avatar_url.
- Login por username ou e-mail.
- Fica logado até "Sair" ou apagar o app; reinstalar pede login de novo.
- "Sair" mantém os dados no iPhone; entrar de novo mostra tudo.
- Todo o progresso vive no banco; ao entrar, a conta já tem todos os treinos e o histórico.
- Programas do treinador vêm do servidor, só para quem está logado.
- Os dados de teste atuais podem ser apagados; ele começa do zero. Apagar o banco do Render só depois do ok dele, na hora.
- A senha inicial fica no `.env` da API (fora do git); ele troca antes de publicar.
- Tela de login: opção A, marca no centro (abaixo).

## Tela de login (opção A)

Fundo `black`. Centralizado verticalmente: 不屈 grande (fonte kanji, em `tab-idle`, como o selo do topo; decisão do Claude), o wordmark HARD TO SUBMIT logo abaixo (HARD TO em `bone`, SUBMIT em `blood`, estilo `brand-app` em tamanho maior), e os campos:

- `USERNAME OU E-MAIL` (sem autocorreção, sem maiúscula automática, `textContentType` username).
- `SENHA` (seguro, `textContentType` password, para o iOS oferecer o preenchimento de senhas).
- Botão primário "Entrar" (`HTSButton`, `blood`). Desabilitado com campo vazio; mostra estado de carregando.

Erros abaixo do botão, em `redText`:
- Credenciais erradas: "Usuário ou senha incorretos." (nunca diz qual dos dois).
- Sem rede ou servidor fora: "Sem conexão. O login precisa de internet."

Sem link de cadastro, sem "esqueci a senha". Segue as regras de voz (sem exclamação, botão com verbo).

## Comportamento no app

- **Início:** se há sessão salva, o app abre direto na Home (sem rede necessária). Se não, abre o login.
- **Entrar:** chama a API, salva a sessão, faz a sincronização completa (pull) e abre a Home. A Home mostra o nome da conta no lugar de "Atleta".
- **Perfil:** nova seção de conta com nome, username e e-mail (só leitura) e o botão "Sair".
- **Sair:** avisa a API (se houver rede; falha não impede), apaga a sessão do iPhone e volta ao login. O SQLite local fica intacto. Se entrar de novo com a mesma conta, tudo está lá e a sync continua de onde parou.
- **Sessão recusada (401):** se a API disser que a sessão não vale mais (ex.: revogada no servidor), o app volta ao login, mantendo os dados locais.
- **Offline depois de logado:** igual a hoje; a sync tenta quando houver rede.

## Servidor

### Dados

- `account` (só no servidor, não espelhada no SQLite): `id` UUIDv7, `athlete_id` (único, FK `athlete`), `name`, `username`, `email`, `password_hash`, `avatar_url` nulo, `created_at`, `updated_at`, `deleted_at`. Índices únicos em `lower(username)` e `lower(email)` entre as não excluídas. ("user" é palavra reservada no Postgres.)
- `auth_session` (só no servidor): `id`, `account_id`, `token_hash` (SHA-256 do token, único), `created_at`, `last_used_at`, `revoked_at`. O token em si nunca é guardado.
- O nome da conta também vai para `athlete.display_name`, que já sincroniza e alimenta a Home.
- A exportação `db-schema.json` e o `SchemaParityTests` ignoram `account` e `auth_session` (tabelas só do servidor), como já fazem com as colunas `server_*`.

### Senha e token

- Hash com argon2id (`@node-rs/argon2`, binários prontos para o Render; decisão do Claude). Comparação de login sempre roda o hash, mesmo sem conta encontrada, para não revelar se o usuário existe pelo tempo.
- Token de sessão: 32 bytes aleatórios em base64url, devolvido uma vez no login. Sem expiração; vale até ser revogado.
- Login aceita username ou e-mail, sem diferenciar maiúsculas, com espaços aparados.
- Limite simples de tentativas de login por IP e por identificador (10 por 15 min), em memória; o Render roda uma instância só. Responde 429. (Decisão do Claude.)

### Rotas

- `POST /v1/auth/login` `{ identifier, password }` → `{ token, account: { id, name, username, email, avatarUrl }, athleteId }`. 401 genérico em erro.
- `GET /v1/auth/me` → a conta e o `athleteId` da sessão.
- `POST /v1/auth/logout` → revoga a sessão atual. 204.
- Todas as rotas `/v1/*` exceto `login` exigem `Authorization: Bearer <token>` de uma sessão válida; o middleware põe a conta e o `athleteId` no contexto e atualiza `last_used_at` (no máximo uma vez por hora).
- `sync push`: rejeita (403) qualquer linha cujo `athlete_id` (ou `id`, na tabela `athlete`) não seja o da sessão.
- `sync pull` e `GET /v1/athletes/{id}`: o `athleteId` pedido tem que ser o da sessão (403 se não).
- `API_TOKEN` sai do `env.ts`, do Render e do app (`HTS_API_TOKEN` no xcconfig e no Info.plist). ADR 0024 é substituída por uma ADR nova.

### Seed e programas

- `pnpm --filter api db:seed`: cria (ou atualiza, por username) a conta do Leo e o atleta dela, lendo de variáveis de ambiente: `SEED_NAME`, `SEED_USERNAME`, `SEED_EMAIL`, `SEED_PASSWORD`. Valores do Leo: Leonardo Theodoro, leotheodoro, e-mail pessoal (só no `.env`), senha no `.env` local.
- Os programas vêm de `apps/api/seed/starter-plan.json`, no gitignore (mesmo formato do `StarterPlan.json` atual, que é movido para lá, com os vídeos). O seed importa de forma aditiva por nome, como o importador Swift faz hoje: temporada Jiu-Jitsu com Base Volume 1, Base Volume 2 e Novembro e Dezembro (o primeiro como atual), e os livres Manutenção, Mobilidade e Base Grip; vídeos no catálogo de exercícios.
- Isso exige a leitura da notação do treinador ("3 a 4", "6-6-3-3", "12/12", "20 s", "máx") em TypeScript. Ela é portada do `TargetNotation` Swift com casos compartilhados em `packages/fixtures/`, como a regra do repo pede para lógica duplicada.
- `pnpm --filter api db:reset -- --yes`: apaga todos os dados de usuário (todas as tabelas, inclusive contas e sessões). Recusa rodar sem `--yes`. Rodar contra o Render só com o ok do Leo na hora.

## No iPhone

- Sessão (token, `athleteId`, dados da conta) no Keychain, com acessibilidade "depois do primeiro desbloqueio, só este aparelho".
- Apagar e reinstalar o app pede login de novo (decisão do Leo). Como o iOS mantém o Keychain depois de apagar o app, o app guarda uma marca de instalação no `UserDefaults` (que some junto com o app); na abertura, sem essa marca, ele apaga a sessão do Keychain antes de tudo e grava a marca.
- `AppModel` passa a ter estado de autenticação; `ensureLocalAthlete` sai. O atleta local vem da sync depois do login.
- O `StarterPlan.json`, o `LocalSeed/` e o importador Swift saem do app (o importador pode virar referência para o port TS e depois ser removido).
- Migração local única que apaga os dados de teste do SQLite (todas as tabelas de usuário e o estado de sync), para o primeiro login começar limpo.
- O cliente HTSAPI recebe o token da sessão em vez do Info.plist; o openapi.json é regenerado.
- Modos de demonstração e screenshots (`-HTSSeedDemo` etc.) seguem funcionando em DEBUG, com uma sessão falsa local.

## Ordem de virada

1. Merge da API nova; o Render faz deploy e roda as migrations.
2. Com ok do Leo: `db:reset` e `db:seed` contra o banco do Render.
3. App novo no iPhone: abre no login, entra, baixa tudo.

O app antigo no iPhone para de sincronizar depois do passo 1 (o token fixo deixa de valer). É aceito: os dados são de teste.

## Fica com o builder

- Organização dos arquivos, nomes de tipos e a divisão em tickets e PRs.
- Detalhes visuais da tela de login dentro dos tokens e do design-system (tamanhos, espaçamentos, teclado empurrando o conteúdo).
- Como o modo DEBUG simula a sessão.
- Testes: rotas de auth e isolamento por conta (Vitest), fixtures da notação, fluxo de login/sair/401 no app.
