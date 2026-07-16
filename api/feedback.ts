import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        route_id TEXT,
        user_id TEXT,
        created_at INTEGER NOT NULL
      )`);
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

const VALID_TYPES = ['bug', 'wrong_info', 'suggestion', 'other'];

export default async function handler(req: any, res: any) {
  try {
    await ensureSchema();

    if (req.method === 'GET') {
      const limit = Math.min(Math.max(parseInt(String(req.query.limit || '20'), 10) || 20, 1), 100);

      const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
      await turso.execute('DELETE FROM feedback WHERE created_at < ?', [oneDayAgo]);

      const r = await turso.execute({
        sql: 'SELECT id, type, message, route_id, user_id, created_at FROM feedback ORDER BY created_at DESC LIMIT ?',
        args: [limit],
      });
      const items = r.rows.map((row: any) => ({
        id: Number(row.id),
        type: String(row.type),
        message: String(row.message),
        routeId: row.route_id != null ? String(row.route_id) : undefined,
        userId: row.user_id != null ? String(row.user_id) : undefined,
        createdAt: Number(row.created_at),
      }));
      return res.status(200).json({ feedback: items });
    }

    if (req.method === 'POST') {
      const { type, message, routeId, userId } = req.body || {};
      if (!type || !message || !VALID_TYPES.includes(type)) {
        return res.status(400).json({ error: 'type and message required' });
      }

      await turso.execute({
        sql: `INSERT INTO feedback (type, message, route_id, user_id, created_at)
              VALUES (?, ?, ?, ?, ?)`,
        args: [
          String(type),
          String(message),
          routeId != null ? String(routeId) : null,
          userId != null ? String(userId) : null,
          Date.now(),
        ],
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Feedback API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
