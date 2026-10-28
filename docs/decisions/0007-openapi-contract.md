# 0007 · Contrato OpenAPI gerado pela API

Data: 2026-10-28 · Status: aceita

## Contexto
O app Swift precisa de um cliente tipado que não divirja da API.

## Decisão
A API gera `packages/contracts/openapi.json` a partir dos schemas Zod (`openapi:generate`). O app gera o cliente com `swift-openapi-generator` (plugin de build) no módulo `HTSAPI`.

## Consequências
Mudou uma rota? Gere o contrato, rode o sync e commite. O cliente Swift é recompilado sozinho.
