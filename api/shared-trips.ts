import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS shared_trips (
        share_token TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        route_id TEXT NOT NULL,
        route_label TEXT NOT NULL,
        next_stop_index INTEGER NOT NULL DEFAULT 0,
        destination_stop_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'EN_ROUTE',
        updated_at INTEGER NOT NULL
      )`);
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

function generateToken(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

export default async function handler(req: any, res: any) {
  try {
    await ensureSchema();

    if (req.method === 'GET') {
      const token = String(req.query.token || '');
      if (!token) {
        return res.status(400).json({ error: 'token required' });
      }

      const row = await turso.execute({
        sql: 'SELECT share_token, user_id, user_name, route_id, route_label, next_stop_index, destination_stop_name, status, updated_at FROM shared_trips WHERE share_token = ?',
        args: [token],
      });

      if (row.rows.length === 0) {
        return res.status(404).json({ error: 'Trip not found' });
      }

      const r = row.rows[0] as any;
      return res.status(200).json({
        shareToken: String(r.share_token),
        userId: String(r.user_id),
        userName: String(r.user_name),
        routeId: String(r.route_id),
        routeLabel: String(r.route_label),
        nextStopIndex: Number(r.next_stop_index),
        destinationStopName: String(r.destination_stop_name),
        status: String(r.status),
        updatedAt: Number(r.updated_at),
      });
    }

    if (req.method === 'POST') {
      const { userId, userName, routeId, routeLabel, nextStopIndex, destinationStopName, status } = req.body || {};
      if (!userId || !userName || !routeId || !routeLabel || !destinationStopName) {
        return res.status(400).json({ error: 'missing fields' });
      }

      const shareToken = generateToken();
      await turso.execute({
        sql: `INSERT INTO shared_trips (share_token, user_id, user_name, route_id, route_label, next_stop_index, destination_stop_name, status, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        args: [
          shareToken,
          String(userId),
          String(userName),
          String(routeId),
          String(routeLabel),
          Math.max(0, Number(nextStopIndex) || 0),
          String(destinationStopName),
          status ? String(status) : 'EN_ROUTE',
          Date.now(),
        ],
      });

      return res.status(200).json({ shareToken });
    }

    if (req.method === 'PATCH') {
      const { token, nextStopIndex, status } = req.body || {};
      if (!token) {
        return res.status(400).json({ error: 'token required' });
      }

      const updates: string[] = [];
      const args: any[] = [];
      if (typeof nextStopIndex === 'number') {
        updates.push('next_stop_index = ?');
        args.push(nextStopIndex);
      }
      if (status) {
        updates.push('status = ?');
        args.push(status);
      }
      updates.push('updated_at = ?');
      args.push(Date.now());

      if (updates.length === 1) {
        return res.status(200).json({ ok: true });
      }

      args.push(token);
      await turso.execute({
        sql: `UPDATE shared_trips SET ${updates.join(', ')} WHERE share_token = ?`,
        args,
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Shared trips API error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
