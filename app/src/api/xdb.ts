export interface XdbRow {
  id?: string;
  [k: string]: unknown;
}

const baseUrl = () => (import.meta.env.VITE_XDB_API_URL as string) ?? 'http://localhost:9990';

export async function fetchAbcList(accessToken: string): Promise<XdbRow[]> {
  const res = await fetch(`${baseUrl()}/abc`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`
    },
    body: JSON.stringify({
      what: 'find',
      from: 'xyany',
      some: 'PRODUCTS.SHEET',
      size: '50'
    })
  });
  if (!res.ok) throw new Error(`XDB /abc ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return Array.isArray(data) ? data : (data.rows ?? data.items ?? data.data ?? []);
}

export async function fetchFilesList(accessToken: string): Promise<XdbRow[]> {
  const res = await fetch(`${baseUrl()}/files`, {
    headers: { Authorization: `Bearer ${accessToken}` }
  });
  if (!res.ok) throw new Error(`XDB /files ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return Array.isArray(data) ? data : (data.rows ?? data.items ?? data.data ?? []);
}
