# 0004 · API em TypeScript com Hono e @hono/zod-openapi

Data: 2026-10-28 · Status: aceita

## Contexto
A API é pequena e serve um app nativo. Queremos validação e contrato saindo da mesma definição.

## Decisão
TypeScript em Node LTS (24), Hono com `@hono/zod-openapi`, testes em Vitest. Config por variáveis de ambiente validadas com Zod.

## Consequências
Os schemas Zod são a fonte do contrato OpenAPI (ver 0007).
