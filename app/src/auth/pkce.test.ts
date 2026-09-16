import { describe, expect, it, vi } from 'vitest';
import {
  apiScope,
  clientId,
  codeChallengeS256,
  newCodeVerifier,
  newState,
  xidAuthority
} from './pkce';

const URLSAFE = /^[A-Za-z0-9_-]+$/;

describe('PKCE (RFC 7636)', () => {
  it('codeChallengeS256 coincide con el vector oficial', async () => {
    // Apéndice B de RFC 7636.
    const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
    await expect(codeChallengeS256(verifier)).resolves.toBe(
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'
    );
  });

  it('newCodeVerifier genera 86 caracteres url-safe únicos', async () => {
    const a = await newCodeVerifier();
    const b = await newCodeVerifier();
    expect(a).toMatch(URLSAFE);
    expect(a).toHaveLength(86); // 64 bytes en base64url sin padding
    expect(a).not.toBe(b);
  });

  it('newState genera 22 caracteres url-safe únicos', () => {
    const a = newState();
    expect(a).toMatch(URLSAFE);
    expect(a).toHaveLength(22); // 16 bytes en base64url sin padding
    expect(a).not.toBe(newState());
  });
});

describe('configuración', () => {
  it('usa valores por defecto sin env', () => {
    expect(xidAuthority()).toBe('http://localhost:8787/common');
    expect(clientId()).toBe('my-webapp');
    expect(apiScope()).toBe('api://my-webapp/access_as_user');
  });

  it('recorta el slash final de la authority', () => {
    vi.stubEnv('VITE_XID_AUTHORITY', 'http://localhost:8787/common/');
    expect(xidAuthority()).toBe('http://localhost:8787/common');
    vi.unstubAllEnvs();
  });
});
