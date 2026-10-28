# 0006 · Monorepo com pnpm workspaces e Turborepo

Data: 2026-10-28 · Status: aceita

## Contexto
App, API, tokens, regras de progressão e contrato mudam juntos.

## Decisão
Um repositório. pnpm workspaces + Turborepo para a parte TS; o app iOS mora em `apps/ios`. Arquivos compartilhados vivem em `packages/` e são copiados para o HTSKit por `pnpm sync:shared`, versionados nos dois lugares.

## Consequências
O CI verifica que o resultado do sync está commitado. O Xcode não depende de Node para compilar.
