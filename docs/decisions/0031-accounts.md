# 0031 · Contas e sessões

Data: 2026-10-30 · Status: aceita (decisão do Leo; spec `docs/superpowers/specs/2026-10-30-auth-design.md`). Substitui a 0024.

## Contexto
O app vai para a App Store aberta, mas só quem tem conta entra. O token fixo da 0024 ficaria embutido no binário público e daria acesso a toda a API.

## Decisão
- `account` (nome, username, e-mail, hash da senha, avatar_url) ligada 1:1 ao `athlete`. Username e e-mail são únicos sem diferenciar maiúsculas. Contas são criadas pelo seed, sem cadastro no app.
- Senha com argon2id (`@node-rs/argon2`). Sem conta encontrada, o login verifica contra um hash isca, para o tempo não revelar se o usuário existe; a resposta de erro é a mesma (`invalid_credentials`).
- `auth_session`: um token aleatório de 32 bytes por login, sem expiração, até o logout. O banco guarda só o SHA-256.
- Limite de 10 falhas de login em 15 min por IP e por identificador, em memória (uma instância no Render).
- `/v1/*` exige a sessão (menos `POST /v1/auth/login`). Cada sessão só lê e grava o próprio atleta: atletas, sync pull e sync push.
- `account` e `auth_session` ficam só no servidor: fora do SQLite, do `db-schema.json` e da sync.

## Consequências
- `API_TOKEN` sai do Render e `HTS_API_TOKEN` sai do app.
- Perder o iPhone = revogar a sessão no banco (`revoked_at`).
- Recuperar senha não existe por enquanto: troca direto no banco pelo seed.
