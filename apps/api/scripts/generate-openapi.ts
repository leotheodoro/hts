import { writeFileSync } from "node:fs";
import { createApp, openApiDocument } from "../src/app.js";
import { createDb } from "../src/db/client.js";

// postgres-js connects lazily, so no database is needed to build the document.
const { db, close } = createDb("postgres://unused@localhost/unused");
const doc = openApiDocument(createApp({ db, apiToken: "unused-token-for-the-openapi-document" }));
await close();

const out = new URL("../../../packages/contracts/openapi.json", import.meta.url);
writeFileSync(out, `${JSON.stringify(doc, null, 2)}\n`);
console.log(`Wrote ${out.pathname}`);
