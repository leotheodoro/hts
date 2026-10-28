// Arquivo gerado, não editar.
// Fonte: packages/design-tokens/tokens.json (v1). Rode `pnpm sync:shared`.
// swift-format-ignore-file

import CoreGraphics
import SwiftUI

/// Cores da marca. Use `Color.hts.<nome>`.
public struct HTSColors: Sendable {
    /// Preto. Fundo de toda peça e de toda tela, base da rashguard. Cerca de 60% da área.
    public let black = Color(.sRGB, red: 0.043, green: 0.043, blue: 0.043) // #0B0B0B
    /// Carvão. Cards e painéis da marca sobre `black`. Cerca de 15%.
    public let charcoal = Color(.sRGB, red: 0.078, green: 0.078, blue: 0.078) // #141414
    /// Superfície do app minimalista: o card com entalhe de cada tela.
    public let surface = Color(.sRGB, red: 0.082, green: 0.082, blue: 0.082) // #151515
    /// Linha. Bordas de card e divisores. Decorativa, nunca a única pista de um controle (1.4:1 em `black`).
    public let line = Color(.sRGB, red: 0.18, green: 0.169, blue: 0.161) // #2E2B29
    /// Borda do botão fantasma e da caixa de check vazia. Vem do canvas; 2.1:1 em `black`, abaixo do 3:1 pedido para bordas de controle, então o rótulo do botão precisa ser legível sozinho.
    public let lineStrong = Color(.sRGB, red: 0.29, green: 0.271, blue: 0.255) // #4A4541
    /// Trilho de barras de progresso e divisores finos do app.
    public let track = Color(.sRGB, red: 0.133, green: 0.133, blue: 0.133) // #222222
    /// Osso. Texto principal e marca em uma cor sobre `black`, `charcoal` e `surface` (14.7:1 ou mais). Cerca de 15%.
    public let bone = Color(.sRGB, red: 0.929, green: 0.902, blue: 0.855) // #EDE6DA
    /// Cinza. Texto secundário e rótulos em mono sobre `black` e `charcoal` (6.8:1 ou mais).
    public let grey = Color(.sRGB, red: 0.639, green: 0.612, blue: 0.573) // #A39C92
    /// Cinza do app. Texto secundário sobre `black` e `surface` no app (6.0:1 ou mais).
    public let greyApp = Color(.sRGB, red: 0.604, green: 0.576, blue: 0.541) // #9A938A
    /// Ícone e rótulo de aba inativa no app. Vem do canvas; 3.6:1 em `black`, passa para o ícone, mas o rótulo de 11px fica abaixo de 4.5:1.
    public let tabIdle = Color(.sRGB, red: 0.435, green: 0.412, blue: 0.384) // #6F6962
    /// Sangue (Pantone 186 C). Ação principal, SUBMIT, carimbo, fita de alerta, barra do wordmark. Até 10% da peça. Nunca em texto pequeno: 3.4:1 em `black`, só marcas e texto de 24px ou mais.
    public let blood = Color(.sRGB, red: 0.784, green: 0.063, blue: 0.18) // #C8102E
    /// Texto sobre `blood`, como o rótulo do botão principal (4.7:1).
    public let onBlood = Color(.sRGB, red: 0.929, green: 0.902, blue: 0.855) // #EDE6DA
    /// Fundo do card de alerta (alvo de competição) com borda `blood`.
    public let bloodDeep = Color(.sRGB, red: 0.102, green: 0.043, blue: 0.051) // #1A0B0D
    /// Vermelho texto. Texto vermelho sobre `black` (4.65:1) e sobre `blood-deep` (4.5:1). Sobre `charcoal` e `surface` cai para 4.3:1: lá, só em 19px negrito ou maior.
    public let redText = Color(.sRGB, red: 0.898, green: 0.22, blue: 0.231) // #E5383B
    /// Oliva. Só em tags e fundo de patente.
    public let olive = Color(.sRGB, red: 0.227, green: 0.227, blue: 0.165) // #3A3A2A
    /// Texto de tag sobre `olive` (7.6:1).
    public let oliveInk = Color(.sRGB, red: 0.851, green: 0.824, blue: 0.722) // #D9D2B8
    /// Cáqui. Divisas e contorno das patentes E a B (7.1:1 sobre `rank-fill`).
    public let khaki = Color(.sRGB, red: 0.71, green: 0.659, blue: 0.529) // #B5A887
    /// Fundo do escudo das patentes.
    public let rankFill = Color(.sRGB, red: 0.118, green: 0.118, blue: 0.086) // #1E1E16
    /// Metal dog tag. Placa de recorde pessoal e etiqueta interna.
    public let tag = Color(.sRGB, red: 0.788, green: 0.761, blue: 0.714) // #C9C2B6
    /// Borda interna da dog tag.
    public let tagEdge = Color(.sRGB, red: 0.659, green: 0.627, blue: 0.584) // #A8A095
    /// Texto em mono sobre `tag` (9.9:1).
    public let tagInk = Color(.sRGB, red: 0.102, green: 0.098, blue: 0.094) // #1A1918
    /// Anel de foco: 2px sólido, 2px afastado, em `bone` sobre qualquer fundo escuro da marca (14.7:1 ou mais).
    public let focus = Color(.sRGB, red: 0.929, green: 0.902, blue: 0.855) // #EDE6DA
}

extension Color {
    public static let hts = HTSColors()
}

/// Espaçamentos em pt (base de 4).
public enum HTSSpacing {
    /// Entre título e legenda colados.
    public static let space1: CGFloat = 4
    /// Entre tags, entre ícone e rótulo.
    public static let space2: CGFloat = 8
    /// Entre linhas relacionadas, gap de grade de cores.
    public static let space3: CGFloat = 12
    /// Entre blocos de um card.
    public static let space4: CGFloat = 16
    /// Margem lateral do app e padding de card.
    public static let space5: CGFloat = 20
    /// Gap entre colunas de componentes.
    public static let space6: CGFloat = 24
    /// Entre seções de uma tela do app; passo da fita de alerta.
    public static let space7: CGFloat = 28
    /// Padding de painel grande, entre seções de exercício.
    public static let space8: CGFloat = 32
    /// Entre colunas de banner.
    public static let space12: CGFloat = 48
    /// Entre seções de peça e de banner.
    public static let space16: CGFloat = 64
    /// Margem lateral de banner 1440 px.
    public static let space20: CGFloat = 80
}

/// Tamanho do corte do entalhe, em pt.
public enum HTSNotch {
    /// Botão principal do app.
    public static let sm: CGFloat = 8
    /// Botão principal da marca.
    public static let md: CGFloat = 10
    /// Card de 390 px de largura; regra geral, 3% da menor medida.
    public static let lg: CGFloat = 12
}

/// Espessuras de traço, em pt.
public enum HTSStroke {
    /// Bordas de card, divisores, borda de tag de alerta.
    public static let hair: CGFloat = 1
    /// Fio vermelho sob cabeçalho, barra de progresso do treino.
    public static let rule: CGFloat = 2
    /// Barra vermelha do wordmark em tela, barra de XP.
    public static let bar: CGFloat = 4
}

/// Opacidades.
public enum HTSOpacity {
    /// Grão monocromático sobre `black` em banner e peça. Nunca no app.
    public static let grain: CGFloat = 0.09
    /// Bloco seguinte ainda não iniciado, no treino ativo.
    public static let next: CGFloat = 0.55
}

/// Família tipográfica, pela chave de tokens.json.
public enum HTSFontFamily: String, Sendable, CaseIterable {
    case stencil
    case display
    case ui
    case body
    case mono
    case kanji
}

/// Estilo de texto. `lineHeight` e `tracking` em pt.
public struct HTSTextStyle: Sendable, Hashable {
    public let name: String
    public let family: HTSFontFamily
    public let size: CGFloat
    public let weight: Int
    public let lineHeight: CGFloat
    public let tracking: CGFloat
    public let uppercase: Bool
}

extension HTSTextStyle {
    /// Título de banner e de peça. Caixa alta.
    public static let brandHero = HTSTextStyle(name: "brand-hero", family: .stencil, size: 112, weight: 900, lineHeight: 95.2, tracking: 1.12, uppercase: true)
    /// Wordmark empilhado e momentos de clímax. Caixa alta.
    public static let brandStack = HTSTextStyle(name: "brand-stack", family: .stencil, size: 64, weight: 900, lineHeight: 52.48, tracking: 0, uppercase: true)
    /// Só o HTS no topo do app.
    public static let brandApp = HTSTextStyle(name: "brand-app", family: .stencil, size: 22, weight: 900, lineHeight: 22, tracking: 0.44, uppercase: true)
    /// Subtítulo de banner, nome de coleção. Caixa alta.
    public static let pieceTitle = HTSTextStyle(name: "piece-title", family: .display, size: 34, weight: 900, lineHeight: 34, tracking: 1.36, uppercase: true)
    /// Rótulo de forma, nome de peça em ficha. Caixa alta.
    public static let pieceSub = HTSTextStyle(name: "piece-sub", family: .display, size: 22, weight: 800, lineHeight: 24.2, tracking: 0, uppercase: true)
    /// Número grande do app: descanso, contador.
    public static let uiDisplay = HTSTextStyle(name: "ui-display", family: .ui, size: 44, weight: 600, lineHeight: 44, tracking: 0, uppercase: false)
    /// Título de tela.
    public static let uiTitle = HTSTextStyle(name: "ui-title", family: .ui, size: 28, weight: 600, lineHeight: 30.8, tracking: -0.28, uppercase: false)
    /// Título de seção e de exercício.
    public static let uiSection = HTSTextStyle(name: "ui-section", family: .ui, size: 20, weight: 600, lineHeight: 24, tracking: -0.2, uppercase: false)
    /// Textos, descrições.
    public static let body = HTSTextStyle(name: "body", family: .body, size: 15, weight: 400, lineHeight: 22, tracking: 0, uppercase: false)
    /// Rótulo de linha, item de lista.
    public static let bodyStrong = HTSTextStyle(name: "body-strong", family: .body, size: 15, weight: 500, lineHeight: 22, tracking: 0, uppercase: false)
    /// Legendas e metadados, em `grey` ou `grey-app`.
    public static let caption = HTSTextStyle(name: "caption", family: .body, size: 13, weight: 400, lineHeight: 18, tracking: 0, uppercase: false)
    /// Recorde, carga e tempo em destaque.
    public static let data = HTSTextStyle(name: "data", family: .mono, size: 24, weight: 600, lineHeight: 26.4, tracking: 0, uppercase: false)
    /// Ficha técnica, numeração, linha de dog tag.
    public static let dataSm = HTSTextStyle(name: "data-sm", family: .mono, size: 13, weight: 500, lineHeight: 18, tracking: 0, uppercase: false)
    /// Rótulo em caixa alta, em `grey`.
    public static let label = HTSTextStyle(name: "label", family: .mono, size: 12, weight: 600, lineHeight: 16, tracking: 1.68, uppercase: false)
    /// O kanji da marca fora do patch e do selo.
    public static let kanji = HTSTextStyle(name: "kanji", family: .kanji, size: 56, weight: 900, lineHeight: 56, tracking: 0, uppercase: false)

    public static let all: [HTSTextStyle] = [.brandHero, .brandStack, .brandApp, .pieceTitle, .pieceSub, .uiDisplay, .uiTitle, .uiSection, .body, .bodyStrong, .caption, .data, .dataSm, .label, .kanji]
}
