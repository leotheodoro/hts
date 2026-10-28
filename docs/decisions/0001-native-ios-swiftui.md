# 0001 · App iOS nativo em SwiftUI

Data: 2026-10-28 · Status: aceita

## Contexto
O treino ativo precisa de timer confiável em segundo plano, vibração com tela bloqueada, wake lock e funcionamento offline. PWA e React Native resolvem isso pior ou com mais camadas.

## Decisão
App só para iPhone, deployment target iOS 26, Swift 6 com strict concurrency, SwiftUI e `@Observable`. Só tema escuro e só retrato. Bundle id `com.hardtosubmit.app`, nome exibido "HTS".

## Consequências
Sem Android por enquanto. Acesso direto a APIs nativas (notificações locais, Live Activities, haptics) quando os tickets de treino ativo chegarem.
