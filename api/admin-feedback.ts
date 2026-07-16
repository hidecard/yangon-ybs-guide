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
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  if (!(await verify(req))) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const limit = Math.min(Math.max(parseInt(String(req.query.limit || '20'), 10) || 20, 1), 100);
  const offset = Math.max(parseInt(String(req.query.offset || '0'), 10) || 0, 0);

  const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
  await turso.execute('DELETE FROM feedback WHERE created_at < ?', [oneDayAgo]);

  const countRow = await turso.execute('SELECT COUNT(*) as total FROM feedback WHERE created_at >= ?', [oneDayAgo]);
  const total = Number((countRow.rows[0] as any).total);

  const r = await turso.execute({
    sql: 'SELECT id, type, message, route_id, user_id, created_at FROM feedback WHERE created_at >= ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
    args: [oneDayAgo, limit, offset],
  });
  const items = r.rows.map((row: any) => ({
    id: Number(row.id),
    type: String(row.type),
    message: String(row.message),
    routeId: row.route_id != null ? String(row.route_id) : undefined,
    userId: row.user_id != null ? String(row.user_id) : undefined,
    createdAt: Number(row.created_at),
  }));
  return res.status(200).json({ feedback: items, total, limit, offset });
}
