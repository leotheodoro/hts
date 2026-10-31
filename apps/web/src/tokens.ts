import tokens from "@hts/design-tokens/tokens.json";

// The design tokens as CSS custom properties (`--blood`, `--space-4`, `--notch-lg`, `--font-stencil`):
// tokens.json stays the only source of the brand's values, as in the app.

interface Token {
  name: string;
  value: string;
}

const groups = ["color", "spacing", "notch", "opacity", "stroke", "radius"] as const;

function resolve(value: string, byName: Map<string, string>): string {
  const reference = /^\{(.+)\}$/.exec(value);
  return reference?.[1] ? resolve(byName.get(reference[1]) ?? value, byName) : value;
}

export function tokenCss(): string {
  const all = groups.flatMap(
    (group) => ((tokens as Record<string, { tokens?: Token[] }>)[group]?.tokens ?? []) as Token[],
  );
  const byName = new Map(all.map((token) => [token.name, token.value]));
  const lines = all.map((token) => `--${token.name}: ${resolve(token.value, byName)};`);
  for (const [family, stack] of Object.entries(tokens.type.families)) {
    lines.push(`--font-${family}: ${stack};`);
  }
  return `:root{${lines.join("")}}`;
}
