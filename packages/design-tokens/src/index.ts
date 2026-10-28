import { readFileSync, writeFileSync } from "node:fs";
import { renderSwift } from "./swift.js";
import type { TokenFile } from "./tokens.js";

export { renderSwift } from "./swift.js";
export * from "./tokens.js";

export const tokensPath = new URL("../tokens.json", import.meta.url);
export const swiftOutputPath = new URL(
  "../../../apps/ios/HTSKit/Sources/HTSDesign/Generated/Tokens.swift",
  import.meta.url,
);

export function loadTokens(): TokenFile {
  return JSON.parse(readFileSync(tokensPath, "utf8")) as TokenFile;
}

export function writeSwiftTokens(): URL {
  writeFileSync(swiftOutputPath, renderSwift(loadTokens()));
  return swiftOutputPath;
}
