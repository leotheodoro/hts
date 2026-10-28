# 0008 · Offline-first

Data: 2026-10-28 · Status: aceita

## Contexto
Na academia nem sempre há rede, e uma sessão em andamento não pode depender dela.

## Decisão
O app grava primeiro no SQLite local e sincroniza com a API depois. A sincronização fica para um ticket próprio, mas o schema já segue as convenções dela: ids gerados no cliente, `updated_at` e exclusão lógica por `deleted_at`.

## Consequências
A API não é fonte da verdade do treino em andamento. Conflitos serão resolvidos no ticket de sync.
