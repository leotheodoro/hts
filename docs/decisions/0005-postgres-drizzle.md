# 0005 · Postgres com Drizzle ORM

Data: 2026-10-28 · Status: aceita

## Contexto
Padrão de outros projetos do autor (Pine). SQL tipado e migrations geradas.

## Decisão
Postgres, driver `postgres` (postgres-js), Drizzle ORM e drizzle-kit. Migrations em `apps/api/drizzle`, scripts `db:generate` e `db:migrate`.

## Consequências
Migrations SQL revisáveis no PR. O schema do SQLite local é mantido à mão para espelhar o do Drizzle.
