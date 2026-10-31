import { defineConfig } from "astro/config";

// Static site on Vercel (Root Directory: apps/web). Pages in pt-BR at the root, English under /en,
// except the privacy policy, whose URLs (/privacidade, /privacy) go to Garmin and must never change (#159).
export default defineConfig({
  site: "https://hardtosubmit.com",
  trailingSlash: "ignore",
});
