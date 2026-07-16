import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = 'hidecard969aky';

async function verify(req: any): Promise<boolean> {
  const auth = req.headers.authorization || '';
  if (auth.startsWith('Bearer ')) {
    return auth.slice(7) === ADMIN_PASSWORD;
  }
  return false;
}

export default async function handler(req: any, res: any) {
  try {
    if (req.method === 'GET') {
      if (!(await verify(req))) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const limit = Math.min(Math.max(parseInt(String(req.query.limit || '50'), 10) || 50, 1), 200);
      const r = await turso.execute({
        sql: 'SELECT id, title, message, type, created_at FROM notifications ORDER BY created_at DESC LIMIT ?',
        args: [limit],
      });
      const items = r.rows.map((row: any) => ({
        id: Number(row.id),
        title: String(row.title),
        message: String(row.message),
        type: String(row.type),
        createdAt: Number(row.created_at),
      }));
      return res.status(200).json({ notifications: items });
    }

    if (req.method === 'POST') {
      if (!(await verify(req))) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const { title, message, type } = req.body || {};
      if (!title || !message) {
        return res.status(400).json({ error: 'title and message required' });
      }

      await turso.execute({
        sql: `INSERT INTO notifications (title, message, type, created_at) VALUES (?, ?, ?, ?)`,
        args: [
          String(title),
          String(message),
          type != null ? String(type) : 'info',
          Date.now(),
        ],
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Notifications API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
