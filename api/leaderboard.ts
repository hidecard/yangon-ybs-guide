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
      await turso.execute(`CREATE TABLE IF NOT EXISTS update_votes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        update_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        vote INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )`);
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_update_votes_update ON update_votes(update_id)`
      );
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_update_votes_device ON update_votes(device_id, update_id)`
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

    const action = String(req.query.action || '');

    if (action === 'vote') {
      if (req.method === 'POST') {
        if (!checkRequestSize(req, 1024)) {
          return jsonError(res, 413, 'Payload too large');
        }

        const rate = await enforceRateLimit(req, res, 'votes', 20);
        if (!rate) return;

        const { update_id, device_id, vote } = req.body || {};
        if (!update_id || !device_id || ![1, -1].includes(vote)) {
          return jsonError(res, 400, 'update_id, device_id, vote (1 or -1) required');
        }

        const updateId = Number(update_id);
        if (!Number.isInteger(updateId) || updateId <= 0) {
          return jsonError(res, 400, 'Invalid update_id');
        }

        const deviceId = sanitizeInput(device_id, 100);
        if (!deviceId) {
          return jsonError(res, 400, 'Invalid device_id');
        }

        const voteValue = Number(vote);

        const existing = await turso.execute(
          'SELECT id, vote FROM update_votes WHERE update_id = ? AND device_id = ?',
          [updateId, deviceId]
        );

        if (existing.rows.length > 0) {
          const row = existing.rows[0] as any;
          const currentVote = Number(row.vote);
          if (currentVote === voteValue) {
            return jsonError(res, 400, 'Already voted');
          }

          const voteId = Number(row.id);
          await turso.execute('UPDATE update_votes SET vote = ? WHERE id = ?', [voteValue, voteId]);

          const scoreDelta = voteValue - currentVote;
          await turso.execute(
            'UPDATE bus_updates SET upvotes = upvotes + ? WHERE id = ?',
            [scoreDelta, updateId]
          );
        } else {
          await turso.execute(
            'INSERT INTO update_votes (update_id, device_id, vote, created_at) VALUES (?, ?, ?, ?)',
            [updateId, deviceId, voteValue, Date.now()]
          );
          await turso.execute(
            'UPDATE bus_updates SET upvotes = upvotes + ? WHERE id = ?',
            [voteValue, updateId]
          );
        }

        const updated = await turso.execute(
          'SELECT upvotes, user_id FROM bus_updates WHERE id = ?',
          [updateId]
        );
        const newScore = Number((updated.rows[0] as any)?.upvotes ?? 0);
        const posterId = String((updated.rows[0] as any)?.user_id ?? '');

        if (voteValue === 1 && newScore >= 3 && posterId) {
          const voterPoints = await turso.execute(
            'SELECT total_points FROM leaderboard_users WHERE device_id = ?',
            [deviceId]
          );
          if (voterPoints.rows.length > 0) {
            const current = Number(voterPoints.rows[0].total_points ?? 0);
            await turso.execute(
              'UPDATE leaderboard_users SET total_points = ?, updated_at = ? WHERE device_id = ?',
              [current + 1, Date.now(), deviceId]
            );
            await turso.execute(
              `INSERT INTO points_history (device_id, points_changed, reason, reference_id, created_at)
               VALUES (?, ?, ?, ?, ?)`,
              [deviceId, 1, 'vote_up', `update_${updateId}`, Date.now()]
            );
          }
        }

        if (voteValue === 1 && newScore === 3 && posterId) {
          const update = await turso.execute(
            'SELECT b.route_id, b.type, lu.device_id FROM bus_updates b JOIN leaderboard_users lu ON b.user_id = lu.device_id WHERE b.id = ?',
            [updateId]
          );
          if (update.rows.length > 0) {
            const row = update.rows[0] as any;
            const posterDeviceId = String(row.device_id);
            const type = String(row.type);
            const points = getPoints(type);
            const posterPoints = await turso.execute(
              'SELECT total_points FROM leaderboard_users WHERE device_id = ?',
              [posterDeviceId]
            );
            if (posterPoints.rows.length > 0) {
              const current = Number(posterPoints.rows[0].total_points ?? 0);
              await turso.execute(
                'UPDATE leaderboard_users SET total_points = ?, updated_at = ? WHERE device_id = ?',
                [current + points, Date.now(), posterDeviceId]
              );
              await turso.execute(
                `INSERT INTO points_history (device_id, points_changed, reason, reference_id, created_at)
                 VALUES (?, ?, ?, ?, ?)`,
                [posterDeviceId, points, 'update_verified', `update_${updateId}`, Date.now()]
              );
            }
          }
        }

        return res.status(200).json({ ok: true, upvotes: newScore, vote: voteValue });
      }

      if (req.method === 'GET') {
        if (!checkRequestSize(req, 1024)) {
          return jsonError(res, 413, 'Payload too large');
        }
        const updateId = Number(req.query?.update_id || 0);
        const deviceId = String(req.query?.device_id || '');
        if (!updateId || !deviceId) {
          return jsonError(res, 400, 'update_id and device_id required');
        }

        const myVoteRow = await turso.execute(
          'SELECT vote FROM update_votes WHERE update_id = ? AND device_id = ?',
          [updateId, deviceId]
        );
        const myVote = myVoteRow.rows.length > 0 ? Number((myVoteRow.rows[0] as any).vote) : 0;

        const totals = await turso.execute(
          'SELECT vote, COUNT(*) as cnt FROM update_votes WHERE update_id = ? GROUP BY vote',
          [updateId]
        );
        let upvotes = 0;
        let downvotes = 0;
        for (const row of totals.rows) {
          const v = Number((row as any).vote);
          const c = Number((row as any).cnt);
          if (v === 1) upvotes = c;
          if (v === -1) downvotes = c;
        }

        return res.status(200).json({ myVote, upvotes, downvotes });
      }

      return jsonError(res, 405, 'Method Not Allowed');
    }

    if (req.method === 'POST' && action === 'register') {
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

    if (req.method === 'POST' && action === 'submit-update') {
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
      if (!cleanDeviceId || !cleanRouteId) {
        return jsonError(res, 400, 'Invalid device_id or route_id');
      }

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

    return jsonError(res, 405, 'Method Not Allowed');
  } catch (error) {
    console.error('Leaderboard API Error:', error);
    return jsonError(res, 500, 'Internal Server Error');
  }
}
