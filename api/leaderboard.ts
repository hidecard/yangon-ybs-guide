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
      await turso.execute(`CREATE TABLE IF NOT EXISTS leaderboard_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        user_name TEXT NOT NULL,
        total_points INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )`);
      await turso.execute(`CREATE TABLE IF NOT EXISTS points_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        points_changed INTEGER NOT NULL,
        reason TEXT NOT NULL,
        reference_id TEXT,
        created_at INTEGER NOT NULL
      )`);
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_leaderboard_points ON leaderboard_users(total_points DESC)`
      );
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_points_history_device ON points_history(device_id, created_at DESC)`
      );
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

const POINTS_MAP: Record<string, number> = {
  started: 10,
  reached: 10,
  road_closed: 15,
  not_running: 10,
  other: 5,
};

function getPoints(type: string): number {
  return POINTS_MAP[type] ?? 5;
}

async function checkRateLimit(deviceId: string): Promise<boolean> {
  const oneHourAgo = Date.now() - 60 * 60 * 1000;
  const r = await turso.execute(
    'SELECT COUNT(*) as cnt FROM points_history WHERE device_id = ? AND reason = ? AND created_at > ?',
    [deviceId, 'news_report', oneHourAgo]
  );
  const cnt = Number(r.rows[0]?.cnt ?? 0);
  return cnt < 2;
}

async function addPoints(
  deviceId: string,
  points: number,
  reason: string,
  referenceId?: string
): Promise<{ ok: boolean; newTotal: number }> {
  const user = await turso.execute(
    'SELECT total_points FROM leaderboard_users WHERE device_id = ?',
    [deviceId]
  );
  if (user.rows.length === 0) {
    return { ok: false, newTotal: 0 };
  }
  const current = Number(user.rows[0].total_points ?? 0);
  const newTotal = Math.max(0, current + points);
  await turso.execute(
    'UPDATE leaderboard_users SET total_points = ?, updated_at = ? WHERE device_id = ?',
    [newTotal, Date.now(), deviceId]
  );
  await turso.execute(
    `INSERT INTO points_history (device_id, points_changed, reason, reference_id, created_at)
     VALUES (?, ?, ?, ?, ?)`,
    [deviceId, points, reason, referenceId ?? null, Date.now()]
  );
  return { ok: true, newTotal };
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    await ensureSchema();

    if (req.method === 'POST' && req.query?.action === 'register') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'leaderboard-register', 5);
      if (!rate) return;

      const { device_id, user_name } = req.body || {};
      if (!device_id || !user_name) {
        return jsonError(res, 400, 'device_id and user_name required');
      }

      const cleanDeviceId = sanitizeInput(device_id, 100);
      const trimmedName = sanitizeInput(user_name, 30) || '';
      if (trimmedName.length < 2) {
        return jsonError(res, 400, 'user_name must be at least 2 characters');
      }

      const now = Date.now();
      await turso.execute(
        `INSERT INTO leaderboard_users (device_id, user_name, total_points, created_at, updated_at)
         VALUES (?, ?, 0, ?, ?)
         ON CONFLICT(device_id) DO UPDATE SET
           user_name = excluded.user_name,
           updated_at = excluded.updated_at`,
        [cleanDeviceId, trimmedName, now, now]
      );
      return res.status(200).json({ ok: true, user_name: trimmedName, total_points: 0 });
    }

    if (req.method === 'GET') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      const limit = Math.min(
        Math.max(parseInt(String(req.query?.limit || '100'), 10) || 100, 1),
        200
      );
      const scope = String(req.query?.scope || 'all');
      const deviceId = String(req.query?.device_id || '');

      let timeFilter = '';
      if (scope === 'monthly') {
        const monthStart = new Date();
        monthStart.setDate(1);
        monthStart.setHours(0, 0, 0, 0);
        timeFilter = `AND ph.created_at >= ${monthStart.getTime()}`;
      }

      const leaderboard = await turso.execute({
        sql: `
          SELECT lu.device_id, lu.user_name, COALESCE(SUM(ph.points_changed), 0) as total_points
          FROM leaderboard_users lu
          LEFT JOIN points_history ph ON lu.device_id = ph.device_id ${timeFilter}
          GROUP BY lu.device_id, lu.user_name
          ORDER BY total_points DESC
          LIMIT ?
        `,
        args: [limit],
      });

      const entries = leaderboard.rows.map((row: any, idx: number) => ({
        rank: idx + 1,
        device_id: String(row.device_id),
        user_name: String(row.user_name),
        points: Number(row.total_points ?? 0),
      }));

      let myRank = null;
      if (deviceId) {
        const myRow = await turso.execute({
          sql: `
            SELECT lu.device_id, lu.user_name, COALESCE(SUM(ph.points_changed), 0) as total_points
            FROM leaderboard_users lu
            LEFT JOIN points_history ph ON lu.device_id = ph.device_id ${timeFilter}
            WHERE lu.device_id = ?
            GROUP BY lu.device_id, lu.user_name
          `,
          args: [deviceId],
        });
        if (myRow.rows.length > 0) {
          const myPoints = Number(myRow.rows[0].total_points ?? 0);
          const myRankRes = await turso.execute({
            sql: `
              SELECT COUNT(*) as cnt FROM leaderboard_users lu
              LEFT JOIN points_history ph ON lu.device_id = ph.device_id ${timeFilter}
              GROUP BY lu.device_id, lu.user_name
              HAVING COALESCE(SUM(ph.points_changed), 0) > ?
            `,
            args: [myPoints],
          });
          const rank = Number(myRankRes.rows[0]?.cnt ?? 0) + 1;
          myRank = {
            rank,
            user_name: String(myRow.rows[0].user_name),
            points: myPoints,
          };
        }
      }

      return res.status(200).json({ leaderboard: entries, my_rank: myRank });
    }

    if (req.method === 'POST' && req.query?.action === 'submit-update') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'leaderboard-submit', 10);
      if (!rate) return;

      const { device_id, route_id, type, stop, note, lat, lng } = req.body || {};
      if (!device_id || !route_id || !type) {
        return jsonError(res, 400, 'device_id, route_id, type required');
      }

      const validTypes = ['started', 'reached', 'road_closed', 'not_running', 'other'];
      try {
        validateEnum(type, validTypes, 'type');
      } catch (e: any) {
        return jsonError(res, 400, e.message);
      }

      const cleanDeviceId = sanitizeInput(device_id, 100);
      const cleanRouteId = sanitizeInput(route_id, 100);

      if (!(await checkRateLimit(cleanDeviceId))) {
        return jsonError(res, 429, 'Rate limit exceeded. Max 2 updates per hour.');
      }

      const user = await turso.execute(
        'SELECT id FROM leaderboard_users WHERE device_id = ?',
        [cleanDeviceId]
      );
      if (user.rows.length === 0) {
        return jsonError(res, 400, 'User not registered. Please set your name first.');
      }

      const points = getPoints(type);
      const result = await addPoints(cleanDeviceId, points, 'news_report', `${cleanRouteId}:${Date.now()}`);
      return res.status(200).json({
        ok: true,
        points_earned: points,
        new_total: result.newTotal,
      });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Leaderboard API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
