import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS telegram_users (
        user_id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        username TEXT,
        first_name TEXT,
        linked_at INTEGER
      )`);
      await turso.execute(`CREATE TABLE IF NOT EXISTS destination_alerts (
        chat_id TEXT PRIMARY KEY,
        user_id TEXT,
        target_lat REAL NOT NULL,
        target_lng REAL NOT NULL,
        target_stop_name TEXT NOT NULL,
        created_at INTEGER
      )`);
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

export default async function handler(req: any, res: any) {
  try {
    await ensureSchema();

    // GET /api/alert?userId=...  -> current link + alert status
    if (req.method === 'GET') {
      const userId = String(req.query.userId || '');
      if (!userId) return res.status(400).json({ error: 'userId required' });

      const user = await turso.execute({
        sql: 'SELECT chat_id FROM telegram_users WHERE user_id = ?',
        args: [userId],
      });

      if (user.rows.length === 0) {
        return res.status(200).json({ linked: false, alert: null });
      }

      const chatId = String(user.rows[0].chat_id);
      const alert = await turso.execute({
        sql: 'SELECT target_stop_name, created_at FROM destination_alerts WHERE chat_id = ?',
        args: [chatId],
      });

      return res.status(200).json({
        linked: true,
        alert: alert.rows.length > 0 ? { stopName: String(alert.rows[0].target_stop_name) } : null,
      });
    }

    // DELETE /api/alert  -> cancel alert  body: { userId }
    if (req.method === 'DELETE') {
      const userId = String(req.body?.userId || '');
      if (!userId) return res.status(400).json({ error: 'userId required' });

      const user = await turso.execute({
        sql: 'SELECT chat_id FROM telegram_users WHERE user_id = ?',
        args: [userId],
      });
      if (user.rows.length > 0) {
        await turso.execute({
          sql: 'DELETE FROM destination_alerts WHERE chat_id = ?',
          args: [String(user.rows[0].chat_id)],
        });
      }
      return res.status(200).json({ ok: true });
    }

    // POST /api/alert  -> create/update alert  body: { userId, lat, lng, stopName }
    if (req.method === 'POST') {
      const { userId, lat, lng, stopName } = req.body || {};
      if (!userId || typeof lat !== 'number' || typeof lng !== 'number' || !stopName) {
        return res.status(400).json({ error: 'userId, lat, lng, stopName required' });
      }

      const user = await turso.execute({
        sql: 'SELECT chat_id FROM telegram_users WHERE user_id = ?',
        args: [userId],
      });

      if (user.rows.length === 0) {
        return res.status(400).json({
          error: 'not_linked',
          message: 'Telegram နှင့် မချိတ်ဆက်ရသေးပါ။ ဦးစွာ "Telegram နဲ့ ချိတ်ဆက်မည်" ကို နှိပ်ပါ။',
        });
      }

      const chatId = String(user.rows[0].chat_id);
      await turso.execute({
        sql: `INSERT INTO destination_alerts (chat_id, user_id, target_lat, target_lng, target_stop_name, created_at)
              VALUES (?, ?, ?, ?, ?, ?)
              ON CONFLICT(chat_id) DO UPDATE SET
                user_id = excluded.user_id,
                target_lat = excluded.target_lat,
                target_lng = excluded.target_lng,
                target_stop_name = excluded.target_stop_name,
                created_at = excluded.created_at`,
        args: [chatId, userId, lat, lng, stopName, Date.now()],
      });

      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Alert API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
