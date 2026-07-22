import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  sanitizeInput,
  sanitizeRich,
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
      await turso.execute(`CREATE TABLE IF NOT EXISTS rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        cost INTEGER NOT NULL,
        stock INTEGER DEFAULT -1,
        icon TEXT,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL
      )`);
      await turso.execute(`CREATE TABLE IF NOT EXISTS redemptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        reward_id INTEGER NOT NULL,
        points_spent INTEGER NOT NULL,
        claim_contact TEXT,
        status TEXT DEFAULT 'pending',
        note TEXT,
        created_at INTEGER NOT NULL
      )`);
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_redemptions_device ON redemptions(device_id, created_at DESC)`
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

    if (req.method === 'GET') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      const activeOnly = req.query?.active !== 'false';
      let sql = 'SELECT id, title, description, cost, stock, icon, is_active FROM rewards';
      const args: any[] = [];
      if (activeOnly) {
        sql += ' WHERE is_active = 1';
      }
      sql += ' ORDER BY cost ASC';
      const r = await turso.execute({ sql, args });
      const rewards = r.rows.map((row: any) => ({
        id: Number(row.id),
        title: String(row.title),
        description: row.description ? String(row.description) : '',
        cost: Number(row.cost),
        stock: row.stock != null ? Number(row.stock) : -1,
        icon: row.icon ? String(row.icon) : '🎁',
        isActive: Number(row.is_active) === 1,
      }));
      return res.status(200).json({ rewards });
    }

    if (req.method === 'POST') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'rewards', 10);
      if (!rate) return;

      const { device_id, reward_id, claim_contact } = req.body || {};
      if (!device_id || !reward_id || !claim_contact) {
        return jsonError(res, 400, 'device_id, reward_id, claim_contact required');
      }

      const cleanDeviceId = sanitizeInput(device_id, 100);
      const cleanClaimContact = sanitizeInput(claim_contact, 200);
      const rewardIdNum = Number(reward_id);
      if (!Number.isInteger(rewardIdNum) || rewardIdNum <= 0) {
        return jsonError(res, 400, 'Invalid reward_id');
      }

      const reward = await turso.execute(
        'SELECT id, title, cost, stock, is_active FROM rewards WHERE id = ?',
        [rewardIdNum]
      );
      if (reward.rows.length === 0) {
        return jsonError(res, 404, 'Reward not found');
      }
      const r = reward.rows[0];
      if (Number(r.is_active) !== 1) {
        return jsonError(res, 400, 'Reward is not available');
      }
      const cost = Number(r.cost);
      const stock = r.stock != null ? Number(r.stock) : -1;
      if (stock === 0) {
        return jsonError(res, 400, 'Out of stock');
      }

      const user = await turso.execute(
        'SELECT total_points FROM leaderboard_users WHERE device_id = ?',
        [cleanDeviceId]
      );
      if (user.rows.length === 0) {
        return jsonError(res, 400, 'User not registered');
      }
      const currentPoints = Number(user.rows[0].total_points ?? 0);
      if (currentPoints < cost) {
        return res.status(400).json({
          error: 'Not enough points',
          required: cost,
          current: currentPoints,
        });
      }

      const newTotal = currentPoints - cost;
      await turso.execute(
        'UPDATE leaderboard_users SET total_points = ?, updated_at = ? WHERE device_id = ?',
        [newTotal, Date.now(), cleanDeviceId]
      );
      await turso.execute(
        `INSERT INTO points_history (device_id, points_changed, reason, reference_id, created_at)
         VALUES (?, ?, ?, ?, ?)`,
        [cleanDeviceId, -cost, 'gift_redeem', `reward_${reward_id}`, Date.now()]
      );

      if (stock > 0) {
        await turso.execute(
          'UPDATE rewards SET stock = stock - 1 WHERE id = ?',
          [rewardIdNum]
        );
      }

      await turso.execute(
        `INSERT INTO redemptions (device_id, reward_id, points_spent, claim_contact, status, note, created_at)
         VALUES (?, ?, ?, ?, 'pending', '', ?)`,
        [cleanDeviceId, rewardIdNum, cost, cleanClaimContact, Date.now()]
      );

      return res.status(200).json({
        ok: true,
        points_spent: cost,
        new_total: newTotal,
        reward_title: String(r.title),
      });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Rewards API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
