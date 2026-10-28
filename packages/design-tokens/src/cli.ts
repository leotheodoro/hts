import { mkdirSync } from "node:fs";
import { swiftOutputPath, writeSwiftTokens } from "./index.js";

mkdirSync(new URL(".", swiftOutputPath), { recursive: true });
console.log(`Wrote ${writeSwiftTokens().pathname}`);
