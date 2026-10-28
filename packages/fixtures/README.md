# Fixtures compartilhados

Cada arquivo testa uma função. Cada caso tem `name`, `input` e `expected`.
Os testes de `packages/progression` (Vitest) e de `HTSDomain` (Swift Testing) rodam os mesmos arquivos.
`pnpm sync:shared` copia os JSON para `apps/ios/HTSKit/Tests/HTSDomainTests/Fixtures`.
