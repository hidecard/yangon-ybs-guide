import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  sanitizeInput,
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

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    await ensureSchema();

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
          const pointsMap: Record<string, number> = {
            started: 10,
            reached: 10,
            road_closed: 15,
            not_running: 10,
            other: 5,
          };
          const points = pointsMap[type] ?? 5;
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

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Votes API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
