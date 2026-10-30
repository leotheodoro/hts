import { hash, verify } from "@node-rs/argon2";

// argon2id with the library defaults (docs/decisions/0031).
export function hashPassword(plain: string): Promise<string> {
  return hash(plain);
}

let decoy: Promise<string> | undefined;

/**
 * Checks a password against a stored hash. With no account (`stored` null) it still runs a full
 * verification against a decoy hash, so a wrong username takes as long as a wrong password.
 */
export async function verifyPassword(stored: string | null, plain: string): Promise<boolean> {
  decoy ??= hash("hts-decoy-password");
  const target = stored ?? (await decoy);
  const matches = await verify(target, plain).catch(() => false);
  return stored !== null && matches;
}
