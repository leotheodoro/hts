import {
  camelCase,
  lineHeightPoints,
  parseEm,
  parseHex,
  parsePx,
  resolveTokens,
  type Token,
  type TokenFile,
} from "./tokens.js";

// Families written in caps per docs/design/design-system.md.
const UPPERCASE_FAMILIES = new Set(["stencil", "display"]);

const num = (n: number) => {
  const rounded = Math.round(n * 1000) / 1000;
  return Number.isInteger(rounded) ? rounded.toFixed(0) : String(rounded);
};

const doc = (usage: string | undefined, indent: string) =>
  usage ? `${indent}/// ${usage.replace(/\s+/g, " ").trim()}\n` : "";

const stripPrefix = (name: string, prefix: string) =>
  name.startsWith(`${prefix}-`) ? name.slice(prefix.length + 1) : name;

function numberEnum(
  typeName: string,
  summary: string,
  tokens: Token[],
  prefix: string,
  parse: (v: string) => number,
) {
  const members = tokens
    .map((t) => {
      const name = camelCase(prefix === "space" ? t.name : stripPrefix(t.name, prefix));
      return `${doc(t.usage, "    ")}    public static let ${name}: CGFloat = ${num(parse(t.value))}`;
    })
    .join("\n");
  return `/// ${summary}\npublic enum ${typeName} {\n${members}\n}\n`;
}

export function renderSwift(tokens: TokenFile): string {
  const colors = resolveTokens(tokens.color.tokens);
  const colorMembers = tokens.color.tokens
    .map((t) => {
      const value = colors.get(t.name) ?? t.value;
      const [r, g, b] = parseHex(value).map((c) => num(c / 255));
      return `${doc(t.usage, "    ")}    public let ${camelCase(t.name)} = Color(.sRGB, red: ${r}, green: ${g}, blue: ${b}) // ${value}`;
    })
    .join("\n");

  const families = Object.keys(tokens.type.families);
  const familyEnum = families.map((f) => `    case ${f}`).join("\n");

  const styleMembers = tokens.type.groups
    .flatMap((group) =>
      group.styles.map((s) => {
        const size = parsePx(s.fontSize);
        const tracking = s.letterSpacing ? parseEm(s.letterSpacing, size) : 0;
        const args = [
          `name: "${s.name}"`,
          `family: .${group.family}`,
          `size: ${num(size)}`,
          `weight: ${s.fontWeight}`,
          `lineHeight: ${num(lineHeightPoints(s.lineHeight, size))}`,
          `tracking: ${num(tracking)}`,
          `uppercase: ${UPPERCASE_FAMILIES.has(group.family)}`,
        ].join(", ");
        return `${doc(s.usage, "    ")}    public static let ${camelCase(s.name)} = HTSTextStyle(${args})`;
      }),
    )
    .join("\n");

  return `// Arquivo gerado, não editar.
// Fonte: packages/design-tokens/tokens.json (v${tokens.version}). Rode \`pnpm sync:shared\`.
// swift-format-ignore-file

import CoreGraphics
import SwiftUI

/// Cores da marca. Use \`Color.hts.<nome>\`.
public struct HTSColors: Sendable {
${colorMembers}
}

extension Color {
    public static let hts = HTSColors()
}

${numberEnum("HTSSpacing", "Espaçamentos em pt (base de 4).", tokens.spacing.tokens, "space", parsePx)}
${numberEnum("HTSNotch", "Tamanho do corte do entalhe, em pt.", tokens.notch.tokens, "notch", parsePx)}
${numberEnum("HTSStroke", "Espessuras de traço, em pt.", tokens.stroke.tokens, "stroke", parsePx)}
${numberEnum("HTSOpacity", "Opacidades.", tokens.opacity.tokens, "opacity", Number)}
/// Família tipográfica, pela chave de tokens.json.
public enum HTSFontFamily: String, Sendable, CaseIterable {
${familyEnum}
}

/// Estilo de texto. \`lineHeight\` e \`tracking\` em pt.
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
${styleMembers}

    public static let all: [HTSTextStyle] = [${tokens.type.groups
      .flatMap((g) => g.styles.map((s) => `.${camelCase(s.name)}`))
      .join(", ")}]
}
`;
}
