import { describe, expect, it } from "vitest";
import { loadTokens, renderSwift } from "../src/index.js";
import { lineHeightPoints, parseEm, parseHex, resolveTokens } from "../src/tokens.js";

describe("resolveTokens", () => {
  it("resolves references, including chains", () => {
    const resolved = resolveTokens([
      { name: "bone", value: "#EDE6DA" },
      { name: "on-blood", value: "{bone}" },
      { name: "focus", value: "{on-blood}" },
    ]);
    expect(resolved.get("on-blood")).toBe("#EDE6DA");
    expect(resolved.get("focus")).toBe("#EDE6DA");
  });

  it("rejects unknown and circular references", () => {
    expect(() => resolveTokens([{ name: "a", value: "{missing}" }])).toThrow(/Unknown/);
    expect(() =>
      resolveTokens([
        { name: "a", value: "{b}" },
        { name: "b", value: "{a}" },
      ]),
    ).toThrow(/Circular/);
  });
});

describe("units", () => {
  it("converts em tracking and line heights to points", () => {
    expect(parseEm("0.02em", 22)).toBeCloseTo(0.44);
    expect(lineHeightPoints(1.1, 28)).toBeCloseTo(30.8);
    expect(lineHeightPoints("22px", 15)).toBe(22);
    expect(parseHex("#C8102E")).toEqual([200, 16, 46]);
  });
});

describe("renderSwift", () => {
  const swift = renderSwift(loadTokens());

  it("marks the file as generated", () => {
    expect(swift.startsWith("// Arquivo gerado, não editar.")).toBe(true);
  });

  it("emits resolved colors and text styles", () => {
    expect(swift).toContain(
      "public let onBlood = Color(.sRGB, red: 0.929, green: 0.902, blue: 0.855) // #EDE6DA",
    );
    expect(swift).toContain(
      'public static let brandApp = HTSTextStyle(name: "brand-app", family: .stencil, size: 22, weight: 900, lineHeight: 22, tracking: 0.44, uppercase: true)',
    );
    expect(swift).toContain("public static let space5: CGFloat = 20");
    expect(swift).toContain("public static let sm: CGFloat = 8");
  });
});
