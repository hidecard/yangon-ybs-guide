import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    return res.status(200).json({});
  }

  if (req.method === 'POST') {
    const { password } = req.body || {};
    if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) {
      return res.status(401).json({ error: 'Invalid password' });
    }
    return res.status(200).json({ ok: true, token: ADMIN_PASSWORD });
  }

  if (req.method === 'GET') {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (!token || token !== ADMIN_PASSWORD) {
      return res.status(401).json({ error: 'Invalid or expired session' });
    }
    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method Not Allowed' });
}
