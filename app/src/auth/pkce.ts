/*
 * Login Authorization Code + PKCE (S256) contra XID, sin librerías (sin MSAL):
 * XID puede usar HTTP local y aquí no hay validación de scheme (distinto con MSAL).
 * 
 * Endpoints reales de xid (src/entra.js):
 *   /{tenant}/oauth2/v2.0/authorize (GET)
 *   /{tenant}/oauth2/v2.0/token (POST)
 *   /{tenant}/openid/userinfo (GET)
 *   /{tenant}/oauth2/v2.0/logout (GET)
 * 
 * El flujo público no exige secreto ni registro de client_id:
 * basta que cumpla "no vacío" y que coincida entre authorize y token.
*/

const SESSION_KEY = 'xid.session';
const PENDING_KEY = 'xid.pending';

export interface PendingLogin {
  state: string;
  codeVerifier: string;
  redirectUri: string;
}

export interface AuthSession {
  accessToken: string;
  idToken?: string;
  refreshToken?: string;
  expiresAt: number;
  username?: string;
}

export function xidAuthority(): string {
  const raw = (import.meta.env.VITE_XID_AUTHORITY as string) ?? 'http://localhost:8787/common';
  return raw.replace(/\/$/, '');
}

export function clientId(): string {
  return (import.meta.env.VITE_XID_CLIENT_ID as string) ?? 'my-webapp';
}

export function apiScope(): string {
  return (import.meta.env.VITE_XDB_API_SCOPE as string) ?? 'api://my-webapp/access_as_user';
}

function b64url(bytes: Uint8Array): string {
  let s = '';
  bytes.forEach((b) => (s += String.fromCharCode(b)));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function newCodeVerifier(): Promise<string> {
  return b64url(crypto.getRandomValues(new Uint8Array(64)));
}

export async function codeChallengeS256(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return b64url(new Uint8Array(digest));
}

export function newState(): string {
  return b64url(crypto.getRandomValues(new Uint8Array(16)));
}

/** Paso 1: genera PKCE + state, lo guarda y navega al authorize de XID. */
export async function startLogin(): Promise<void> {
  const authority = xidAuthority();
  const redirectUri = window.location.origin + '/';
  const codeVerifier = await newCodeVerifier();
  const params = new URLSearchParams({
    client_id: clientId(),
    response_type: 'code',
    redirect_uri: redirectUri,
    scope: `openid profile ${apiScope()}`,
    code_challenge: await codeChallengeS256(codeVerifier),
    code_challenge_method: 'S256',
    state: newState()
  });
  const pending: PendingLogin = {
    state: params.get('state') as string,
    codeVerifier,
    redirectUri
  };
  sessionStorage.setItem(PENDING_KEY, JSON.stringify(pending));
  window.location.assign(`${authority}/oauth2/v2.0/authorize?${params}`);
}

interface TokenResponse {
  access_token: string;
  id_token?: string;
  refresh_token?: string;
  expires_in?: number;
}

/** Paso 2: procesa el callback (?code&state), intercambia el code y guarda la sesión. */
export async function handleCallback(): Promise<AuthSession | null> {
  const url = new URL(window.location.href);
  const error = url.searchParams.get('error');
  if (error) {
    throw new Error(`XID: ${error} ${url.searchParams.get('error_description') ?? ''}`.trim());
  }
  const code = url.searchParams.get('code');
  if (!code) return null;
  const raw = sessionStorage.getItem(PENDING_KEY);
  if (!raw) throw new Error('Login perdido: abre el login en la misma pestaña (sessionStorage).');
  const pending = JSON.parse(raw) as PendingLogin;
  if (pending.state !== url.searchParams.get('state')) {
    throw new Error('state no coincide (posible CSRF): reintenta el login.');
  }
  // El code es de un solo uso: se limpia la URL y el pending ANTES del intercambio.
  // Así un segundo montaje (StrictMode en dev ejecuta el efecto dos veces) o un
  // reintento no reutiliza el mismo code (eso producía `invalid or expired code`
  // junto a la tabla ya cargada). Si el intercambio falla, hay que pulsar Login
  // de nuevo porque el code ya no vale.
  window.history.replaceState({}, '', pending.redirectUri);
  sessionStorage.removeItem(PENDING_KEY);
  // Dedup: si ya hay un intercambio en vuelo para este code, se reutiliza.
  const existing = inFlightExchanges.get(code);
  if (existing) return existing;
  const exchange = exchangeCode(code, pending).finally(() => {
    if (inFlightExchanges.get(code) === exchange) inFlightExchanges.delete(code);
  });
  inFlightExchanges.set(code, exchange);
  return exchange;
}

// Intercambios en vuelo por code: evita el doble canje concurrente del mismo code.
const inFlightExchanges = new Map<string, Promise<AuthSession>>();

async function exchangeCode(code: string, pending: PendingLogin): Promise<AuthSession> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: clientId(),
    code,
    redirect_uri: pending.redirectUri,
    code_verifier: pending.codeVerifier
  });
  const res = await fetch(`${xidAuthority()}/oauth2/v2.0/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });
  if (!res.ok) throw new Error(`token ${res.status}: ${await res.text()}`);
  const tok = (await res.json()) as TokenResponse;
  if (!tok.access_token) throw new Error('token sin access_token');
  const session: AuthSession = {
    accessToken: tok.access_token,
    idToken: tok.id_token,
    refreshToken: tok.refresh_token,
    expiresAt: Date.now() + (tok.expires_in ?? 3600) * 1000
  };
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  return session;
}

/** Sesión guardada si existe y no está expirada (margen 60s). */
export function loadSession(): AuthSession | null {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw) as AuthSession;
    if (!session.accessToken || Date.now() > session.expiresAt - 60_000) {
      sessionStorage.removeItem(SESSION_KEY);
      return null;
    }
    return session;
  } catch {
    return null;
  }
}

export async function fetchUsername(accessToken: string): Promise<string | null> {
  try {
    const res = await fetch(`${xidAuthority()}/openid/userinfo`, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    if (!res.ok) return null;
    const info = (await res.json()) as { email?: string; preferred_username?: string; sub?: string };
    return info.email ?? info.preferred_username ?? info.sub ?? null;
  } catch {
    return null;
  }
}

export function logout(): void {
  sessionStorage.removeItem(SESSION_KEY);
  sessionStorage.removeItem(PENDING_KEY);
  // Cierra la sesión también en XID (dev admite el redirect sin allowlist).
  const back = encodeURIComponent(window.location.origin + '/');
  window.location.assign(
    `${xidAuthority()}/oauth2/v2.0/logout?post_logout_redirect_uri=${back}`
  );
}
