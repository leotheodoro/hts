export interface Token {
  name: string;
  value: string;
  usage?: string;
}

export interface TextStyle {
  name: string;
  fontSize: string;
  lineHeight: number | string;
  fontWeight: number;
  letterSpacing?: string;
  sample?: string;
  usage?: string;
}

export interface TokenFile {
  name: string;
  version: number;
  color: { tokens: Token[] };
  type: {
    families: Record<string, string>;
    groups: { name: string; family: string; styles: TextStyle[] }[];
  };
  spacing: { tokens: Token[] };
  notch: { tokens: Token[] };
  stroke: { tokens: Token[] };
  opacity: { tokens: Token[] };
}

const REFERENCE = /^\{([\w-]+)\}$/;

/** Resolves `{name}` references against tokens of the same list, following chains. */
export function resolveTokens(tokens: Token[]): Map<string, string> {
  const byName = new Map(tokens.map((t) => [t.name, t.value]));
  const resolve = (name: string, seen: string[]): string => {
    const value = byName.get(name);
    if (value === undefined) throw new Error(`Unknown token reference {${name}}`);
    const ref = REFERENCE.exec(value)?.[1];
    if (!ref) return value;
    if (seen.includes(ref))
      throw new Error(`Circular token reference: ${[...seen, ref].join(" -> ")}`);
    return resolve(ref, [...seen, ref]);
  };
  return new Map(tokens.map((t) => [t.name, resolve(t.name, [t.name])]));
}

/** "4px" -> 4, "0" -> 0. Only px and unitless values are valid in the app. */
export function parsePx(value: string): number {
  const match = /^(-?\d+(?:\.\d+)?)(px)?$/.exec(value.trim());
  if (!match?.[1]) throw new Error(`Expected a px value, got "${value}"`);
  return Number(match[1]);
}

/** "0.02em" at 22px -> 0.44 pt. */
export function parseEm(value: string, fontSize: number): number {
  const match = /^(-?\d+(?:\.\d+)?)em$/.exec(value.trim());
  if (!match?.[1]) throw new Error(`Expected an em value, got "${value}"`);
  return Number(match[1]) * fontSize;
}

/** Unitless line heights are multipliers of the font size; px values are absolute. */
export function lineHeightPoints(lineHeight: number | string, fontSize: number): number {
  return typeof lineHeight === "number" ? lineHeight * fontSize : parsePx(lineHeight);
}

export function parseHex(value: string): [number, number, number] {
  const match = /^#([0-9a-f]{6})$/i.exec(value);
  if (!match?.[1]) throw new Error(`Expected #RRGGBB, got "${value}"`);
  const n = Number.parseInt(match[1], 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}

/** "red-text" -> "redText", "space-1" -> "space1". */
export function camelCase(name: string): string {
  return name.replace(/-([a-z0-9])/g, (_, c: string) => c.toUpperCase());
}
