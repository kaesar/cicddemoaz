import { useEffect, useRef, useState } from 'react';
import {
  AuthSession,
  fetchUsername,
  handleCallback,
  loadSession,
  logout,
  startLogin
} from './auth/pkce';
import { fetchAbcList } from './api/xdb';

// Columnas visibles del grid: id = id, any01 = producto, any02 = valor.
const COLUMNS = [
  { key: 'id', header: 'id' },
  { key: 'any01', header: 'producto' },
  { key: 'any02', header: 'valor' }
];

interface DatagridElement extends HTMLElement {
  data: unknown[];
  columns: { key: string; header: string }[];
}

const str = (v: unknown): string => (v === null || v === undefined ? '' : String(v));

export default function App() {
  const [session, setSession] = useState<AuthSession | null>(null);
  const [username, setUsername] = useState<string>('');
  const [rows, setRows] = useState<unknown[]>([]);
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState(false);

  const loginBtn = useRef<HTMLElement>(null);
  const listBtn = useRef<HTMLElement>(null);
  const logoutBtn = useRef<HTMLElement>(null);
  const gridRef = useRef<DatagridElement>(null);

  useEffect(() => {
    (async () => {
      try {
        // Si venimos del redirect de XID (?code&state), completa el login.
        const completed = await handleCallback().catch((e) => {
          setError(e instanceof Error ? e.message : String(e));
          return null;
        });
        const current = completed ?? loadSession();
        setSession(current);
        if (current && !current.username) {
          const name = await fetchUsername(current.accessToken);
          if (name) {
            current.username = name;
            setUsername(name);
          }
        } else if (current?.username) {
          setUsername(current.username);
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  const login = () => {
    setError('');
    startLogin().catch((e) => setError(e instanceof Error ? e.message : String(e)));
  };

  const doLogout = () => {
    setSession(null);
    setUsername('');
    setRows([]);
    logout();
  };

  const listar = async () => {
    setError('');
    setLoading(true);
    try {
      const current = session ?? loadSession();
      if (!current) throw new Error('Sin sesión: pulsa Login');
      const data = await fetchAbcList(current.accessToken);
      setRows(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  // as-button emite `button-tap` (no click): se enlaza con addEventListener,
  // mismo patrón que ai/templates/chat.html.
  useEffect(() => {
    const el = loginBtn.current;
    if (!el) return;
    el.addEventListener('button-tap', login);
    return () => el.removeEventListener('button-tap', login);
  });
  useEffect(() => {
    const el = listBtn.current;
    if (!el) return;
    el.addEventListener('button-tap', listar);
    return () => el.removeEventListener('button-tap', listar);
  });
  useEffect(() => {
    const el = logoutBtn.current;
    if (!el) return;
    el.addEventListener('button-tap', doLogout);
    return () => el.removeEventListener('button-tap', doLogout);
  });

  // as-datagrid recibe datos por propiedades (.data/.columns), no por atributos.
  useEffect(() => {
    const grid = gridRef.current;
    if (!grid) return;
    grid.columns = COLUMNS;
    grid.data = (rows as Record<string, unknown>[]).map((r) => ({
      id: str(r.id),
      any01: str(r.any01),
      any02: str(r.any02)
    }));
  }, [rows]);

  return (
    <main style={{ fontFamily: 'system-ui', maxWidth: 860, margin: '2rem auto', padding: '0 1rem' }}>
      <as-box>
        <h1 style={{ margin: '0 0 0.5rem' }}>Productos</h1>
        <p style={{ margin: '0 0 1rem' }}>
          Authority: <code>{String(import.meta.env.VITE_XID_AUTHORITY)}</code><br />
          API XDB: <code>{String(import.meta.env.VITE_XDB_API_URL)}/abc</code>
        </p>
        {!session ? (
          <as-button ref={loginBtn} label="Login con XID" variant="primary"></as-button>
        ) : (
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <span>Logueado{username ? <> como <b>{username}</b></> : null}</span>
            <as-button
              ref={listBtn}
              label={loading ? 'Cargando…' : 'Listar datos'}
              variant="primary"
              disabled={loading ? true : undefined}
            ></as-button>
            <as-button ref={logoutBtn} label="Logout" variant="secondary"></as-button>
          </div>
        )}
        {error && <pre style={{ color: 'crimson' }}>{error}</pre>}
      </as-box>
      {session && (
        <div style={{ marginTop: '1rem' }}>
          <as-datagrid ref={gridRef} title="Listado" filterable></as-datagrid>
          {rows.length === 0 && !loading && (
            <p>Sin datos. Pulsa «Listar datos» o ejecuta <code>scripts/seed-xdb.sh</code>.</p>
          )}
        </div>
      )}
    </main>
  );
}
