# Hard To Submit · Handoff para a landing page

31/10/2026 · Leo

O site foi construído em `apps/web` (#159). Este documento continua sendo a base do conteúdo do site público do Hard To Submit. Ele traz o que o app faz, a marca e o conteúdo obrigatório da política de privacidade. A escolha de stack, hospedagem e domínio fica com essa sessão. As decisões que só o Leo pode tomar estão no fim.

## Por que o site existe agora

1. **Pedido de acesso ao Garmin (plano Starter).** O app vai importar treinos do relógio Garmin. O Garmin só aprova o acesso se houver um **site público** e uma **política de privacidade publicada**, em URLs estáveis.
2. **App Store, no futuro.** A Apple também pede uma URL de política de privacidade e uma URL de suporte.
3. **Vitrine da marca.** Hard To Submit é também uma marca de vestuário de BJJ. O site apresenta o app, sem prometer o que ainda não existe.

## Páginas

| Página | Caminho sugerido | Obrigatória |
| --- | --- | --- |
| Landing do app | `/` | Sim |
| Política de privacidade (pt-BR) | `/privacidade` | Sim |
| Privacy policy (inglês, para a revisão do Garmin) | `/privacy` | Sim |
| Suporte e contato | `/suporte` | Sim para a App Store |

As URLs da política não podem mudar depois de enviadas ao Garmin.

## O produto

Hard To Submit é um app de iPhone para registrar a preparação física de quem treina jiu-jitsu, série por série, com timer de descanso. Por cima do registro existe uma camada de progressão: cada série concluída vira XP, nível, patente e atributos.

- **Para quem:** atletas de BJJ que seguem um programa de preparação física. Hoje o uso é fechado: as contas são criadas pelo Leo, e o app não tem cadastro aberto.
- **Plataforma:** iPhone (iOS 26), tema escuro, uso com uma mão na academia. Funciona offline e sincroniza depois.
- **Como funciona:**
  - **Temporadas e arcos.** O ano se divide em temporadas (ex.: Jiu-Jitsu), e cada temporada em arcos: fases com treinos e duração em semanas, liberados em ordem. Os arcos de Manutenção ficam sempre disponíveis.
  - **Treino ativo.** A tela mostra cada exercício com séries, carga e repetições, o valor da última vez ("Anterior") e o timer de descanso, com notificação. Também há vídeo do exercício.
  - **Progressão.** Cada série concluída dá XP. O XP define o nível e a patente: E Recruta, D Soldado, C Cabo, B Sargento, A Tenente e S Comandante.
  - **Atributos.** São cinco: FOR (força), EXP (explosão), GÁS (resistência), COR (core) e MOB (mobilidade). Cada bloco do treino alimenta os seus.
  - **Recordes:** "Limite Quebrado" é uma carga nova máxima num exercício.
  - **Sequência:** semanas seguidas batendo a meta de treinos.
  - **Títulos:** conquistas desbloqueadas pelo treino.
  - **A Batalha:** a competição cadastrada que fecha a temporada.
  - **Diário:** o histórico de treinos, volume e recordes.
  - **Integração com o Garmin (em breve):** corridas e outras atividades do relógio entram no Diário e dão XP. Não usar o logo do Garmin antes da aprovação e sem seguir o kit de marca dele. Até lá, escrever só "Garmin" em texto, como "em breve".
- **Princípio:** a temática envolve, não esconde. Nomes de exercícios, cargas e repetições ficam reais e legíveis.

## Marca

A fonte de verdade é o design system do HTS. O resumo abaixo basta para o site, mas a sessão pode ler as referências completas:

- Handoff do design system: https://claude.ai/artifact/R8wYCjGSN24XG7vcZ1XKBk
- Canvas de design (fileira "versão minimalista"): https://claude.ai/artifact/KzHW9r1MKGRutmzu1niXZ3

### Essência e voz

- **Essência:** marca de BJJ premium para quem não bate. Militar, cru, disciplinado, forte, sóbrio. A força vem do contraste e do peso da tipografia, nunca de enfeite.
- **Kanji da marca:** 不屈 (fukutsu), "indomável, que não se rende". É sempre esses dois caracteres, nessa ordem.
- **Voz:** frases curtas e imperativas, sem exclamação. Exemplos: "Treine.", "Não bata.", "Lembre do objetivo."
- **Botões:** começam pelo verbo, como "Ver o app" ou "Falar com a gente".
- **Proibido:** emoji, exclamação e gíria de academia ("no pain no gain").
- Treinos têm nomes militares: Linha de Frente, Trincheira, Bombardeio, Blindado, Muralha, Fio da Navalha.

### Cores

Preto e osso ocupam cerca de 90% da página. O vermelho é munição: até 10%, só na ação principal e no SUBMIT do wordmark. Não existe tema claro.

| Token | Hex | Uso |
| --- | --- | --- |
| `black` | `#0B0B0B` | Fundo (cerca de 60%) |
| `charcoal` | `#141414` | Cards e painéis |
| `line` | `#2E2B29` | Bordas e divisores |
| `line-strong` | `#4A4541` | Borda de botão secundário |
| `bone` | `#EDE6DA` | Texto principal |
| `grey` | `#A39C92` | Texto secundário, rótulos |
| `blood` | `#C8102E` | Ação principal, SUBMIT. Nunca em texto pequeno nem como fundo dominante |
| `red-text` | `#E5383B` | Texto vermelho (sobre `black`) |
| `blood-deep` | `#1A0B0D` | Fundo de alerta |
| `olive` / `olive-ink` / `khaki` | `#3A3A2A` / `#D9D2B8` / `#B5A887` | Só em patentes e divisas |

### Tipografia (Google Fonts, OFL)

| Papel | Família |
| --- | --- |
| Marca e display | Big Shoulders Stencil Display 900, em caixa alta, entrelinha de 0,82 a 0,9, só em títulos curtos |
| Título de peça | Big Shoulders Display 800 a 900, em caixa alta |
| Título de interface | Inter Tight 600 |
| Corpo | Inter 400 a 500 |
| Dados e rótulos | IBM Plex Mono 500 a 600, rótulos em caixa alta com espaçamento largo |
| Kanji | Noto Serif JP 900 |

- No máximo duas famílias por bloco, além do kanji.
- Números tabulares (`tabular-nums`), com zero à esquerda em dados: "062.5 KG × 06".
- **Wordmark:** HARD TO SUBMIT em estêncil, com HARD TO em `bone` e SUBMIT em `blood`. É o único lugar com estêncil em destaque na interface.

### Forma

- **Entalhe:** é a assinatura. Cards e botões têm os cantos superior esquerdo e inferior direito cortados a 45°, com corte de cerca de 3% da menor medida (12 px num card de 390 px). Fora isso, os cantos são retos.
- **Proibido:** sombra, gradiente, glow e neon.
- **Grão:** um ruído monocromático fino sobre `black`, com opacidade de 0,09, pode ir em fundos de banner e no hero. É o único lugar onde o grão é permitido.
- **Elementos gráficos:** no máximo dois por página. Opções: fita de alerta (listras `blood`/`black` a 45°), carimbo 不屈 girado de 4 a 8°, escudo de patente com divisas e dog tag (para recordes).
- **Espaçamento:** escala de 4 px (4, 8, 12, 16, 20, 24, 28, 32, 48, 64, 80).
- **Foto e ilustração:** P&B de alto contraste, com grão, nanquim ou gravura, e só figuras originais. Proibido: personagens de anime, logos de outras marcas e fotos de pessoas reais sem autorização.
- **Ícones:** traço de 1,6 a 1,8 px, sem preenchimento.
- **Foco de teclado:** contorno sólido de 2 px em `bone`, afastado 2 px.

### Arquivos

- **Ícone do app:** `apps/ios/HTS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, no repositório do app. É o patch com 不屈. O Leo copia esse arquivo para o projeto novo.
- **Logos em SVG** (patch, wordmark, monograma e selo) estão no canvas e no handoff do design system. Não existem no repositório do app.
- **Screenshots do app:** o Leo fornece. Se faltarem, usar molduras de iPhone vazias como marcador, nunca telas inventadas.

## Conteúdo da política de privacidade

O texto precisa ser fiel ao que o app faz hoje, mais o que a integração com o Garmin vai fazer. Escrever em pt-BR e em inglês, com o mesmo conteúdo.

- **Responsável:** Leonardo Theodoro (Hard To Submit). O e-mail de contato é um campo para o Leo preencher. Não inventar um.
- **Dados da conta:** nome, nome de usuário, e-mail e senha. A senha é guardada só como hash (argon2id), nunca em texto. As contas são criadas pelo responsável.
- **Foto de perfil (opcional):** enviada pelo usuário, guardada num bucket privado de armazenamento compatível com S3 (Neon, EUA). Ela só é mostrada por links temporários.
- **Dados de treino:** temporadas, arcos, treinos, séries (carga, repetições, tempo, distância), datas e horários, recordes e competições cadastradas. Ficam no aparelho e são sincronizados com o servidor.
- **Onde ficam:** a API roda no Render (EUA, Virgínia) e o banco Postgres no Neon (EUA, us-east-1). A conexão é sempre HTTPS. A sessão de login fica no Keychain do iPhone.
- **Notificações:** são locais (o fim do descanso). Nenhum serviço de push de terceiros é usado.
- **Garmin (quando ativado pelo usuário):**
  - Com a autorização do usuário no Garmin Connect, o app recebe o resumo de cada atividade nova: tipo, data e hora, duração, distância, FC média e calorias.
  - Os tokens de acesso ficam só no servidor.
  - Os dados servem apenas para mostrar a atividade no histórico e calcular a progressão no app.
  - "Desconectar" encerra o acesso e apaga os tokens. As atividades já importadas ficam no histórico até o usuário pedir a exclusão.
- **O que não fazemos:** sem anúncios, sem venda de dados, sem compartilhamento com terceiros para marketing, sem analytics nem rastreamento de terceiros.
- **Direitos do usuário (LGPD):** pedir acesso, correção e exclusão da conta e de todos os dados pelo e-mail de contato. A exclusão apaga também a foto do bucket.
- **Menores:** o app não é destinado a menores de 13 anos.
- **Mudanças:** a data de atualização fica no topo da página, e mudanças relevantes são avisadas no app.

## O que fica com a sessão nova

- Stack e hospedagem. Um site estático basta. Sugestões: Astro ou HTML puro, com hospedagem gratuita (Render static, Cloudflare Pages ou Vercel).
- Layout e seções da landing, dentro da marca. Exemplo de seções: hero com wordmark e 不屈; como funciona (arcos, treino ativo, progressão e patentes, atributos); integrações (Garmin em breve); chamada final.
- Textos de marketing, na voz da marca.

## Decisões do Leo

1. **Domínio:** hardtosubmit.com.
2. **Chamada principal:** "Em breve na App Store", sem formulário.
3. **E-mail de contato:** contact@hardtosubmit.com.
4. **Idioma:** o site inteiro em pt-BR e inglês.
5. **Marca de vestuário:** ainda não decidido. Escolha do Claude enquanto isso: o site é só do app.
