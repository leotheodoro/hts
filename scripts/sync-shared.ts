// Copies shared sources from packages/ into the HTSKit Swift package.
// The copies are committed; CI runs this script and fails on any diff.
import { copyFileSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { writeSwiftTokens } from "@hts/design-tokens";

const root = fileURLToPath(new URL("..", import.meta.url));
const kit = join(root, "apps/ios/HTSKit");
const log = (path: string) => console.log(`  ${relative(root, path)}`);

function copy(from: string, to: string) {
  mkdirSync(join(to, ".."), { recursive: true });
  copyFileSync(from, to);
  log(to);
}

/** Mirrors the *.json files of a directory, removing stale copies. */
function mirrorJson(fromDir: string, toDir: string) {
  rmSync(toDir, { recursive: true, force: true });
  mkdirSync(toDir, { recursive: true });
  for (const file of readdirSync(fromDir)
    .filter((f) => f.endsWith(".json") && f !== "package.json")
    .sort()) {
    copy(join(fromDir, file), join(toDir, file));
  }
}

console.log("sync:shared");
log(fileURLToPath(writeSwiftTokens()));
copy(
  join(root, "packages/progression/progression.json"),
  join(kit, "Sources/HTSDomain/Resources/progression.json"),
);
mirrorJson(join(root, "packages/fixtures"), join(kit, "Tests/HTSDomainTests/Fixtures"));
copy(join(root, "packages/contracts/openapi.json"), join(kit, "Sources/HTSAPI/openapi.json"));
copy(
  join(root, "packages/contracts/db-schema.json"),
  join(kit, "Tests/HTSPersistenceTests/Resources/db-schema.json"),
);
