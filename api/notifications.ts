import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
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

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'info',
        created_at INTEGER NOT NULL
      )`);
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

async function verify(req: any): Promise<boolean> {
  if (!ADMIN_PASSWORD) return false;
  const auth = req.headers.authorization || '';
  if (auth.startsWith('Bearer ')) {
    return auth.slice(7) === ADMIN_PASSWORD;
  }
  return false;
}

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
      const limit = Math.min(Math.max(parseInt(String(req.query.limit || '10'), 10) || 10, 1), 50);
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
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'notifications', 5);
      if (!rate) return;

      if (!(await verify(req))) {
        return jsonError(res, 401, 'Unauthorized');
      }

      const { title, message, type } = req.body || {};
      if (!title || !message) {
        return jsonError(res, 400, 'title and message required');
      }

      const validTypes = ['info', 'update', 'alert'];
      try {
        validateEnum(type, validTypes, 'type');
      } catch (e: any) {
        return jsonError(res, 400, e.message);
      }

      const cleanTitle = sanitizeRich(title, 200);
      const cleanMessage = sanitizeRich(message, 2000);
      if (!cleanTitle || !cleanMessage) {
        return jsonError(res, 400, 'Invalid title or message');
      }

      const cleanType = type && validTypes.includes(type) ? type : 'info';

      await turso.execute({
        sql: `INSERT INTO notifications (title, message, type, created_at) VALUES (?, ?, ?, ?)`,
        args: [
          cleanTitle,
          cleanMessage,
          cleanType,
          Date.now(),
        ],
      });

      const countRow = await turso.execute('SELECT COUNT(*) as total FROM notifications');
      const total = Number((countRow.rows[0] as any).total);
      if (total > 20) {
        const cutoff = await turso.execute({
          sql: 'SELECT id FROM notifications ORDER BY created_at DESC LIMIT 1 OFFSET ?',
          args: [19],
        });
        if (cutoff.rows.length > 0) {
          const cutoffId = Number((cutoff.rows[0] as any).id);
          await turso.execute('DELETE FROM notifications WHERE id <= ?', [cutoffId]);
        }
      }

      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Notifications API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
