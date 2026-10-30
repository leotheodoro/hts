Hard To Submit é uma marca de BJJ premium para quem não bate. O primeiro produto é uma rashguard de qualidade extrema, tecido premium e alta durabilidade. O kanji da marca é 不屈 (fukutsu): indomável, que não se rende. Este sistema vale para toda peça: rashguard, camiseta, banner, redes e o app de treino.

## Essência

- Atributos: militar, cru, disciplinado, forte, masculino, sóbrio.
- A força vem do contraste e do peso da tipografia, nunca de enfeite.
- Clima de referência: foto P&B granulada com luz dura, academia de boxe, estrada à noite; patch de colete de moto clube; estêncil militar e quadro de treino antigo; gravura clássica e escultura de luta; nanquim de mangá de luta; tipografia vermelha pesada sobre preto; tatuagem em script como detalhe raro.

## Voz

- Frases curtas, imperativas, sem exclamação: "Treine.", "Não bata.", "Lembre do objetivo."
- Botões e chamadas começam pelo verbo: "Iniciar treino", "Ver treino", "Finalizar".
- Nada de emoji, exclamação ou gíria genérica de academia ("no pain no gain").
- Treinos têm nomes militares: Linha de Frente, Trincheira, Bombardeio, Blindado, Paraquedista, Marcha Forçada, Muralha, Escalada, Couraça, Fio da Navalha, Patrulha, Sentinela.

## Marca

A marca tem quatro formas da mesma assinatura. **O Patch é a marca principal**: toda peça nova parte dele.

| Forma | Componente | Arquivos | Onde usar |
| --- | --- | --- | --- |
| B · Patch (principal) | `Patch` | `hts-patch*.svg` | Costas da rashguard, bordado, ícone do app, adesivo |
| A · Wordmark | `Wordmark` | `hts-wordmark*.svg` | Peito da camiseta, banner, splash do app, embalagem |
| C · Monograma | `Monogram` | `hts-monogram*.svg` | Manga, etiqueta, favicon, marca d'água, carimbo pequeno |
| D · Selo | `Seal` | `hts-seal*.svg` | Detalhe de barra, recompensa no app, lacre, edição limitada |

- Cada forma existe em 2 cores e em 1 cor (osso sobre preto, preto sobre osso, vermelho sobre preto). Use a de 2 cores por padrão e a de 1 cor em bordado, silk de 1 cor ou carimbo.
- O centro do patch leva só 不屈. O kanji é sempre 不屈, nessa ordem e nesses caracteres.
- Respiro mínimo em volta de qualquer forma: a altura da letra H do wordmark.
- Tamanho mínimo impresso: wordmark `min-wordmark` (25 mm), monograma `min-monogram` (10 mm), patch `min-patch` (30 mm).
- O estêncil do nome hoje é a Big Shoulders Stencil 900 convertida em curvas. Um estêncil próprio, com cortes e pontes exclusivos, foi decidido; quando chegar, ele substitui as curvas dos quatro logos e do componente, sem mudar proporções.
- Nunca distorça, contorne, ponha sombra ou brilho na marca.

## Cores

Preto e osso ocupam cerca de 90% de qualquer peça. O vermelho é munição.

- Fundo: `black` (cerca de 60%). Cards e painéis: `charcoal`; no app, `surface`. Bordas: `line`.
- Texto: `bone` (cerca de 15%), secundário `grey`; no app, `grey-app`.
- `blood` (Pantone 186 C) só na ação principal, em alerta, em recorde, no SUBMIT, no destaque da marca na borda do arco atual (com o rótulo ATUAL em `red-text`, decisão do Leo no #90) e nos bullets dos blocos feitos no treino ativo (#108), até 10% da peça. Nunca como fundo dominante.
- Arco bloqueado: kanji e nome em `bone` com `opacity-next`.
- Texto vermelho é `red-text`, nunca `blood` em texto pequeno. `red-text` passa sobre `black` e `blood-deep`; sobre `charcoal` e `surface`, só em 19px negrito ou maior.
- `olive` e `olive-ink` só em tags e patentes; `khaki` só nas divisas; `tag`, `tag-edge` e `tag-ink` só na dog tag.
- Não existe tema claro. Em fundo claro, use preto sobre osso, com vermelho só como acento.
- Os Pantone além do 186 C ainda serão definidos no leque físico.

## Tipografia

Todas as famílias são Google Fonts com licença OFL, liberadas para produto vendido. Carregue-as do Google Fonts: Big Shoulders Stencil Display 900, Big Shoulders Display 800 a 900, Inter Tight 600, Inter 400 a 500, IBM Plex Mono 500 a 600, Noto Serif JP 900.

| Papel | Família | Estilos |
| --- | --- | --- |
| Marca e display | `stencil` | `brand-hero`, `brand-stack`, `brand-app` |
| Título de peça | `display` | `piece-title`, `piece-sub` |
| Título de interface | `ui` | `ui-display`, `ui-title`, `ui-section` |
| Corpo | `body` | `body`, `body-strong`, `caption` |
| Dados e especificações | `mono` | `data`, `data-sm`, `label` |
| Kanji | `kanji` | `kanji` |

- Estêncil sempre em caixa alta e entrelinha apertada (0,82 a 0,9), em peças e títulos curtos. No app, aparece só no wordmark do topo (`brand-app`): HARD TO em `bone` e SUBMIT em `blood`, com o selo 不屈 à direita em `tab-idle` (#87).
- Big Shoulders Display em caixa alta.
- No máximo duas famílias por peça, além do kanji.
- Números sempre tabulares (`font-variant-numeric: tabular-nums`), com zero à esquerda em dados de peça: "062.5 KG × 06".
- Em peça impressa, texto em mono nunca abaixo de `min-mono-text` (6 pt).
- Script estilo tatuagem só como detalhe raro, uma frase na barra ou no punho. Ainda não há fonte de script escolhida.

## Elementos gráficos

O entalhe é a assinatura formal. Os outros aparecem um ou dois por peça, nunca todos juntos.

| Elemento | Como é | Uso |
| --- | --- | --- |
| Entalhe (`NotchCard`, `Button`) | Cantos superior esquerdo e inferior direito cortados a `angle-notch`, corte de cerca de 3% da menor medida (`notch-lg` = 12px em 390px) | Cards, botões, monograma, recorte de etiqueta, painel da rashguard |
| Patentes E a S (`Rank`) | Escudo com divisas | Ranks do app, faixa da manga, versões da linha de produtos |
| Dog tag (`DogTag`) | Placa metálica arredondada com furo, texto em mono | Recorde pessoal, etiqueta interna, tag pendurada |
| Fita de alerta (`AlertTape`) | Listras `blood` e `black` a 45° | Alerta de competição, borda de banner, barra da rashguard |
| Grão (`grain.svg`) | Ruído fino monocromático a `opacity-grain` sobre `black` | Fundos de banner e peça. Nunca no app |
| Carimbo 不屈 (`Seal`) | Retângulo girado de 4 a 8° com moldura interna | Lacre, edição limitada, recompensa |
| Rockers | Faixas curvas com o texto acompanhando a curva | Só no patch e em costas de peça |

- Cantos são retos (`radius-none`). A única curva fora do patch é a dog tag (`radius-tag`).
- Sem sombras, sem gradiente, sem glow.

## Patentes e linha de produtos

- A linha de produtos se separa por patente: cada versão leva uma patente, uma rashguard por rank.
- Escala: E Recruta, D Soldado, C Cabo, B Sargento (divisas `khaki`), A Tenente (divisas `bone`), S Comandante (divisas `bone` e estrela `red-text`).
- No app, as mesmas patentes marcam o nível do atleta.

## Ilustração e foto

- P&B de alto contraste, com grão, nanquim ou gravura.
- Personagens e figuras sempre originais.
- Nunca personagens de anime existentes, logos de outras marcas, fotos de pessoas reais ou caveira de moto clube copiada.

## Iconografia

- Ícones de interface em traço de 1,6 a 1,8px, `currentColor`, sem preenchimento, desenhados no próprio app (escudo, linhas, calendário, perfil, check, seta). Ainda não há um conjunto de ícones da marca nos arquivos.
- Nada de emoji.

## Foco e acessibilidade

- Foco de teclado: contorno sólido de 2px em `focus`, afastado 2px. Em botão entalhado, o recorte sai no foco para o contorno aparecer inteiro.
- Pares que ficam abaixo do mínimo e vêm do canvas: borda do botão fantasma em `line-strong` (2.1:1) e rótulo de aba inativa em `tab-idle` (3.6:1). Use-os só onde o rótulo ou o ícone já resolve sozinho.

## Não fazer

- Neon, gradiente, brilho ou glow.
- Vermelho como fundo dominante de uma peça.
- Mais de dois elementos gráficos na mesma peça.
- Estêncil em texto corrido ou em toda a interface do app.
- Kanji diferente de 不屈 na marca, ou kanji decorativo sem significado definido.
- Emoji, exclamação, gíria de academia genérica.
- Distorcer, contornar ou pôr sombra no wordmark.
