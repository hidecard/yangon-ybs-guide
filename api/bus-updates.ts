import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  sanitizeInput,
  sanitizeRich,
  validateEnum,
  enforceRateLimit,
  jsonError,
} from './_security';

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
        upvotes INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )`);
      try {
        await turso.execute('ALTER TABLE bus_updates ADD COLUMN upvotes INTEGER DEFAULT 0');
      } catch {
        // Column may already exist.
      }
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

const VALID_TYPES = ['started', 'reached', 'road_closed', 'not_running', 'other'];

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;

  try {
    await ensureSchema();

    if (req.method === 'GET') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      const routeId = req.query.routeId ? String(req.query.routeId) : null;
      const limit = Math.min(Math.max(parseInt(String(req.query.limit || '50'), 10) || 50, 1), 200);

      const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
      await turso.execute('DELETE FROM bus_updates WHERE created_at < ?', [oneDayAgo]);

      let sql =
        'SELECT id, route_id, stop, type, note, lat, lng, user_id, upvotes, created_at FROM bus_updates';
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
        upvotes: Number(row.upvotes ?? 0),
        createdAt: Number(row.created_at),
      }));
      return res.status(200).json({ updates });
    }

    if (req.method === 'POST') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'bus-updates', 30);
      if (!rate) return;

      const { routeId, stop, type, note, lat, lng, userId } = req.body || {};
      if (!routeId || !type) {
        return jsonError(res, 400, 'routeId and valid type required');
      }

      try {
        validateEnum(type, VALID_TYPES, 'type');
      } catch (e: any) {
        return jsonError(res, 400, e.message);
      }

      const cleanRouteId = sanitizeInput(routeId, 100);
      const cleanStop = sanitizeInput(stop, 100);
      const cleanNote = sanitizeRich(note, 500);
      const cleanUserId = sanitizeInput(userId, 100);

      const latNum = typeof lat === 'number' && Number.isFinite(lat) ? lat : null;
      const lngNum = typeof lng === 'number' && Number.isFinite(lng) ? lng : null;

      await turso.execute({
        sql: `INSERT INTO bus_updates (route_id, stop, type, note, lat, lng, user_id, upvotes, created_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)`,
        args: [
          cleanRouteId,
          cleanStop,
          type,
          cleanNote,
          latNum,
          lngNum,
          cleanUserId,
          Date.now(),
        ],
      });
      const insertResult = await turso.execute('SELECT last_insert_rowid() as id');
      const newId = Number((insertResult.rows[0] as any).id);
      return res.status(200).json({ ok: true, id: newId });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('BusUpdates API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
