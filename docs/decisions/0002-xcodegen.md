# 0002 · Projeto Xcode gerado por XcodeGen

Data: 2026-10-28 · Status: aceita

## Contexto
O `.xcodeproj` gera conflitos de merge difíceis e é ilegível em revisão.

## Decisão
`apps/ios/project.yml` é versionado; o `.xcodeproj` é gerado (`make ios-generate`) e fica no `.gitignore`. A lógica mora no Swift Package local `HTSKit`; o target do app é fino.

## Consequências
Todo mundo (e o CI) precisa do `xcodegen` instalado. Mudanças de configuração de build vão para o `project.yml`, nunca para o Xcode.
