import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const arr = new Uint8Array(32);
  crypto.getRandomValues(arr);
  return Array.from(arr).map(b => chars[b % chars.length]).join('');
}

const sessions = new Map<string, number>();

export default async function handler(req: any, res: any) {
  if (req.method === 'POST') {
    const { password } = req.body || {};
    if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) {
      return res.status(401).json({ error: 'Invalid password' });
    }

    const token = generateToken();
    sessions.set(token, Date.now() + 3600 * 1000);

    return res.status(200).json({ ok: true, token });
  }

  if (req.method === 'GET') {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const expiry = sessions.get(token);
    if (!token || !expiry || Date.now() > expiry) {
      sessions.delete(token);
      return res.status(401).json({ error: 'Invalid or expired session' });
    }
    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method Not Allowed' });
}
