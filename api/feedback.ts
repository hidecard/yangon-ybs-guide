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
  setCORS,
} from './_security';

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
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    await ensureSchema();

    if (req.method === 'GET') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
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
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const ip = req.headers['x-forwarded-for'] || req.connection?.remoteAddress || 'unknown';
      const rate = await enforceRateLimit(req, res, 'feedback', 10);
      if (!rate) return;

      const { type, message, routeId, userId } = req.body || {};
      if (!type || !message) {
        return jsonError(res, 400, 'type and message required');
      }

      try {
        validateEnum(type, VALID_TYPES, 'type');
      } catch (e: any) {
        return jsonError(res, 400, e.message);
      }

      const cleanMessage = sanitizeRich(message, 500);
      if (!cleanMessage) {
        return jsonError(res, 400, 'Invalid message content');
      }

      const cleanRouteId = sanitizeInput(routeId, 100);
      const cleanUserId = sanitizeInput(userId, 100);

      await turso.execute({
        sql: `INSERT INTO feedback (type, message, route_id, user_id, created_at)
              VALUES (?, ?, ?, ?, ?)`,
        args: [
          type,
          cleanMessage,
          cleanRouteId,
          cleanUserId,
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
