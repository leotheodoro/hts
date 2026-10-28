# 0009 · Convenções de dados

Data: 2026-10-28 · Status: aceita

## Decisão
- PK `id` UUIDv7 gerado no cliente (ordenável no tempo, sem colisão entre dispositivos).
- Toda tabela de dado do usuário tem `athlete_id`, `created_at`, `updated_at`, `deleted_at`. Hoje há um atleta só, mas o schema já é multiusuário.
- Datas em UTC: `timestamptz` no Postgres, ISO 8601 no SQLite.
- Pesos em kg com decimal; carga somada em `numeric` no Postgres.
- Mesmos nomes de tabela e coluna nos dois bancos (snake_case, singular).

## Consequências
Nenhum id é gerado pelo servidor. A tabela `athlete` é a raiz e não tem `athlete_id`.
