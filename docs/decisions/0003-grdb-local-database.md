# 0003 · SQLite local via GRDB

Data: 2026-10-28 · Status: aceita

## Contexto
O app é offline-first e o histórico de cargas é o ativo principal. Precisamos de SQL explícito, migrations versionadas e um schema que espelhe o Postgres.

## Decisão
SQLite via GRDB (Swift Package), com `DatabaseMigrator`. Sem SwiftData e sem Core Data.

## Consequências
Schema controlado por nós, com os mesmos nomes do Postgres. Testes usam banco em memória.
