import { useEffect, useState } from 'react';
import { PublicClientApplication, AccountInfo } from '@azure/msal-browser';
import { msalConfig, loginRequest } from './auth/msalConfig';
import { fetchAbcList } from './api/xdb';

const msal = new PublicClientApplication(msalConfig);
let initialized = false;

export default function App() {
  const [account, setAccount] = useState<AccountInfo | null>(null);
  const [rows, setRows] = useState<unknown[]>([]);
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    (async () => {
      if (!initialized) {
        await msal.initialize();
        initialized = true;
      }
      const resp = await msal.handleRedirectPromise().catch((e) => {
        setError(String(e));
        return null;
      });
      const acc = resp?.account ?? msal.getAllAccounts()[0] ?? null;
      if (acc) setAccount(acc);
    })();
  }, []);

  const login = () => msal.loginRedirect(loginRequest);
  const logout = async () => {
    await msal.logoutRedirect({ account: account ?? undefined });
    setAccount(null);
    setRows([]);
  };

  const listar = async () => {
    setError('');
    setLoading(true);
    try {
      const acc = account ?? msal.getAllAccounts()[0];
      if (!acc) throw new Error('Sin sesión: pulsa Login');
      const token = await msal.acquireTokenSilent({ ...loginRequest, account: acc }).catch(() =>
        msal.acquireTokenRedirect(loginRequest)
      );
      const accessToken = typeof token === 'object' && token && 'accessToken' in token
        ? (token as { accessToken: string }).accessToken
        : '';
      const data = await fetchAbcList(accessToken);
      setRows(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main style={{ fontFamily: 'system-ui', maxWidth: 860, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>WebApp Dummy · XID (Entra facade) + XDB</h1>
      <p>
        Authority: <code>{String(import.meta.env.VITE_XID_AUTHORITY)}</code><br />
        API XDB: <code>{String(import.meta.env.VITE_XDB_API_URL)}/abc</code>
      </p>
      {!account ? (
        <button onClick={login}>Login con XID</button>
      ) : (
        <div>
          <p>Logueado como <b>{account.username}</b></p>
          <button onClick={listar} disabled={loading}>{loading ? 'Cargando…' : 'Listar datos'}</button>{' '}
          <button onClick={logout}>Logout</button>
        </div>
      )}
      {error && <pre style={{ color: 'crimson' }}>{error}</pre>}
      {rows.length > 0 && (
        <table border={1} cellPadding={6} style={{ marginTop: 16, borderCollapse: 'collapse' }}>
          <thead><tr>{Object.keys(rows[0] as object).map((k) => <th key={k}>{k}</th>)}</tr></thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i}>{Object.values(r as object).map((v, j) => <td key={j}>{String(v)}</td>)}</tr>
            ))}
          </tbody>
        </table>
      )}
      {account && rows.length === 0 && !loading && <p>Sin datos. Pulsa «Listar datos» o ejecuta <code>scripts/seed-xdb.sh</code>.</p>}
    </main>
  );
}
