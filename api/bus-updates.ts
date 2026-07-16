import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS bus_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        stop TEXT,
        type TEXT NOT NULL,
        note TEXT,
        lat REAL,
        lng REAL,
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

const VALID_TYPES = ['started', 'reached', 'road_closed', 'not_running', 'other'];

export default async function handler(req: any, res: any) {
  try {
    await ensureSchema();

    // GET /api/bus-updates?routeId=...&limit=...  -> recent updates (newest first)
    if (req.method === 'GET') {
      const routeId = req.query.routeId ? String(req.query.routeId) : null;
      const limit = Math.min(Math.max(parseInt(String(req.query.limit || '50'), 10) || 50, 1), 200);

      const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
      await turso.execute('DELETE FROM bus_updates WHERE created_at < ?', [oneDayAgo]);

      let sql =
        'SELECT id, route_id, stop, type, note, lat, lng, user_id, created_at FROM bus_updates';
      const args: any[] = [];
      if (routeId) {
        sql += ' WHERE route_id = ?';
        args.push(routeId);
      }
      sql += ' ORDER BY created_at DESC LIMIT ?';
      args.push(limit);

      const r = await turso.execute({ sql, args });
      const updates = r.rows.map((row: any) => ({
        id: Number(row.id),
        routeId: String(row.route_id),
        stop: row.stop != null ? String(row.stop) : undefined,
        type: String(row.type),
        note: row.note != null ? String(row.note) : undefined,
        lat: row.lat != null ? Number(row.lat) : undefined,
        lng: row.lng != null ? Number(row.lng) : undefined,
        userId: row.user_id != null ? String(row.user_id) : undefined,
        createdAt: Number(row.created_at),
      }));
      return res.status(200).json({ updates });
    }

    // POST /api/bus-updates  body: { routeId, stop?, type, note?, lat?, lng?, userId? }
    if (req.method === 'POST') {
      const { routeId, stop, type, note, lat, lng, userId } = req.body || {};
      if (!routeId || !type || !VALID_TYPES.includes(type)) {
        return res.status(400).json({ error: 'routeId and valid type required' });
      }

      await turso.execute({
        sql: `INSERT INTO bus_updates (route_id, stop, type, note, lat, lng, user_id, created_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        args: [
          String(routeId),
          stop != null ? String(stop) : null,
          String(type),
          note != null ? String(note) : null,
          typeof lat === 'number' ? lat : null,
          typeof lng === 'number' ? lng : null,
          userId != null ? String(userId) : null,
          Date.now(),
        ],
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('BusUpdates API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
