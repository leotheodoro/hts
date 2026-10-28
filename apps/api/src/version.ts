import { readFileSync } from "node:fs";

// Read at runtime so the same code works from src/ (tsx) and dist/ (node).
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  version: string;
};

export const version: string = pkg.version;
