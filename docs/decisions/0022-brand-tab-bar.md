# 0022 · Barra de abas própria

Data: 2026-10-28 · Status: aceita · Substitui a parte de abas da decisão do esqueleto (UIDesignRequiresCompatibility)

## Contexto
No iPhone do Leo, a barra de abas apareceu em Liquid Glass (flutuante, com blur), ignorando as cores `tab-idle` e `bone` (#26). A chave `UIDesignRequiresCompatibility` funcionou no simulador iOS 26.5, mas não vale em todas as versões, e a Apple vai removê-la.

## Decisão
O app desenha a própria barra: opaca em `black`, divisor `line`, abas inativas em `tab-idle` e a ativa em `bone`, alvos de 49 pt. A barra do sistema fica escondida (`.toolbar(.hidden, for: .tabBar)`); o `TabView` continua guardando o estado de cada aba. A chave de compatibilidade fica para o resto da interface enquanto existir.

## Consequências
Igual em qualquer versão do iOS e sem blur nem glow, como pede o design system. Perdemos comportamentos nativos da barra (minimizar ao rolar, acessório de mini player), que o app não usa.
