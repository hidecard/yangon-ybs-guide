import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  jsonError,
  setCORS,
  requireAdmin,
  enforceRateLimit,
  sanitizeInput,
  sanitizeRich,
  validateEnum,
} from './_security';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

let adminSchemaReady: Promise<void> | null = null;
function ensureAdminSchema(): Promise<void> {
  if (!adminSchemaReady) {
    adminSchemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        route_id TEXT,
        user_id TEXT,
        created_at INTEGER NOT NULL
      )`);
    })().catch((e) => {
      adminSchemaReady = null;
      throw e;
    });
  }
  return adminSchemaReady;
}

const EXPORT_TABLES = [
  'rate_limits',
  'feedback',
  'telegram_users',
  'destination_alerts',
  'bus_updates',
  'notifications',
  'leaderboard_users',
  'points_history',
  'rewards',
  'redemptions',
  'update_votes',
];

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    const action = String(req.query.action || '');

    if (action === 'auth') {
      if (req.method === 'POST') {
        if (!checkRequestSize(req, 1024)) {
          return jsonError(res, 413, 'Payload too large');
        }
        const { password } = req.body || {};
        if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) {
          return jsonError(res, 401, 'Invalid password');
        }
        return res.status(200).json({ ok: true });
      }
      if (req.method === 'GET') {
        if (!checkRequestSize(req, 1024)) {
          return jsonError(res, 413, 'Payload too large');
        }
        if (!(await requireAdmin(req, res))) return;
        return res.status(200).json({ ok: true });
      }
      return jsonError(res, 405, 'Method Not Allowed');
    }

    if (action === 'feedback') {
      if (req.method === 'GET') {
        if (!checkRequestSize(req, 1024)) {
          return jsonError(res, 413, 'Payload too large');
        }
        if (!(await requireAdmin(req, res))) return;

        await ensureAdminSchema();

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
      return jsonError(res, 405, 'Method Not Allowed');
    }

    if (action === 'export') {
      if (req.method !== 'GET') {
        return jsonError(res, 405, 'Method Not Allowed');
      }
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      if (!(await requireAdmin(req, res))) return;

      const exportData: Record<string, any[]> = {};
      for (const table of EXPORT_TABLES) {
        try {
          const result = await turso.execute(`SELECT * FROM ${table}`);
          exportData[table] = result.rows;
        } catch {
          exportData[table] = [];
        }
      }

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename="turso-export-${timestamp}.json"`);
      res.setHeader('Cache-Control', 'no-store');
      return res.status(200).json(exportData);
    }

    return jsonError(res, 404, 'Not found');
  } catch (error) {
    console.error('Admin API Error:', error);
    return jsonError(res, 500, 'Internal Server Error');
  }
}
