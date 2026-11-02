import { createHash, randomBytes } from "node:crypto";

// Garmin Connect Developer Program, OAuth2 PKCE specification (#168): the login page, the token endpoint, the
// user id and the registration. Tokens stay on the server (docs/decisions/0033).

const AUTHORIZE_URL = "https://connect.garmin.com/oauth2Confirm";
const TOKEN_URL = "https://diauth.garmin.com/di-oauth2-service/oauth/token";
const USER_ID_URL = "https://apis.garmin.com/wellness-api/rest/user/id";
const REGISTRATION_URL = "https://apis.garmin.com/wellness-api/rest/user/registration";

export interface GarminOAuthConfig {
  clientId: string;
  clientSecret: string;
  /** Registered on the Garmin app; must match exactly. */
  redirectUri: string;
  fetch?: typeof globalThis.fetch | undefined;
}

export interface GarminTokens {
  accessToken: string;
  refreshToken: string;
  /** With a 10 minute margin, as Garmin recommends. */
  expiresAt: Date;
}

/** 43 to 128 characters of A-Z, a-z, 0-9 and "-._~": 48 random bytes in base64url give 64. */
export function codeVerifier(): string {
  return randomBytes(48).toString("base64url");
}

export function codeChallenge(verifier: string): string {
  return createHash("sha256").update(verifier).digest("base64url");
}

export function authorizeUrl(config: GarminOAuthConfig, state: string, verifier: string): string {
  const url = new URL(AUTHORIZE_URL);
  url.search = new URLSearchParams({
    client_id: config.clientId,
    response_type: "code",
    code_challenge: codeChallenge(verifier),
    code_challenge_method: "S256",
    redirect_uri: config.redirectUri,
    state,
  }).toString();
  return url.toString();
}

export class GarminRequestError extends Error {}

async function tokenRequest(
  config: GarminOAuthConfig,
  form: Record<string, string>,
): Promise<GarminTokens> {
  const res = await (config.fetch ?? fetch)(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      ...form,
      client_id: config.clientId,
      client_secret: config.clientSecret,
    }).toString(),
  });
  if (!res.ok) throw new GarminRequestError(`token ${res.status}`);
  const body = (await res.json()) as {
    access_token?: string;
    refresh_token?: string;
    expires_in?: number;
  };
  if (!body.access_token || !body.refresh_token || !body.expires_in) {
    throw new GarminRequestError("token response without tokens");
  }
  return {
    accessToken: body.access_token,
    refreshToken: body.refresh_token,
    expiresAt: new Date(Date.now() + (body.expires_in - 600) * 1000),
  };
}

export function exchangeCode(config: GarminOAuthConfig, code: string, verifier: string) {
  return tokenRequest(config, {
    grant_type: "authorization_code",
    code,
    code_verifier: verifier,
    redirect_uri: config.redirectUri,
  });
}

export function refreshTokens(config: GarminOAuthConfig, refreshToken: string) {
  return tokenRequest(config, { grant_type: "refresh_token", refresh_token: refreshToken });
}

/** The Garmin user id: stable across logins, and what every push carries. */
export async function fetchUserId(config: GarminOAuthConfig, accessToken: string): Promise<string> {
  const res = await (config.fetch ?? fetch)(USER_ID_URL, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new GarminRequestError(`user id ${res.status}`);
  const body = (await res.json()) as { userId?: string };
  if (!body.userId) throw new GarminRequestError("user id response without userId");
  return body.userId;
}

/** Required when the app offers "Desconectar": removes the consent at Garmin. */
export async function deleteRegistration(
  config: GarminOAuthConfig,
  accessToken: string,
): Promise<void> {
  const res = await (config.fetch ?? fetch)(REGISTRATION_URL, {
    method: "DELETE",
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new GarminRequestError(`registration ${res.status}`);
}
