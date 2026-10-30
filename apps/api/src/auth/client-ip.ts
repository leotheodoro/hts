/**
 * The address the login limiter counts. The leftmost X-Forwarded-For value is whatever the client sent,
 * so it is never used: Cloudflare (in front of Render) sets `cf-connecting-ip` itself, and otherwise the
 * rightmost X-Forwarded-For entry is the one the last proxy appended.
 */
export function clientIp(header: (name: string) => string | undefined): string {
  const cloudflare = header("cf-connecting-ip")?.trim();
  if (cloudflare) return cloudflare;
  const forwarded = header("x-forwarded-for")
    ?.split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  return forwarded?.at(-1) ?? "local";
}
