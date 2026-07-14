import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const BOT_TOKEN = process.env.BOT_TOKEN!;

async function sendTelegram(chatId: string, text: string): Promise<boolean> {
  if (!BOT_TOKEN) {
    console.error('[alert] BOT_TOKEN is not set');
    return false;
  }
  try {
    const resp = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
    if (!resp.ok) {
      console.error('[alert] Telegram API error:', resp.status, await resp.text());
      return false;
    }
    return true;
  } catch (e) {
    console.error('[alert] fetch failed:', e);
    return false;
  }
}

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
        user_id TEXT PRIMARY KEY,
        target_stop_name TEXT NOT NULL,
        target_lat REAL NOT NULL,
        target_lng REAL NOT NULL,
        detail TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )`);
      // Add the detail column to any pre-existing table (CREATE IF NOT EXISTS won't alter it)
      await turso.execute(`ALTER TABLE destination_alerts ADD COLUMN detail TEXT`).catch(() => {});
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
        sql: 'SELECT target_stop_name, detail FROM destination_alerts WHERE user_id = ?',
        args: [chatId],
      });

      return res.status(200).json({
        linked: true,
        alert: alert.rows.length > 0
          ? {
              stopName: String(alert.rows[0].target_stop_name),
              detail: alert.rows[0].detail ? String(alert.rows[0].detail) : undefined,
            }
          : null,
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
          sql: 'DELETE FROM destination_alerts WHERE user_id = ?',
          args: [String(user.rows[0].chat_id)],
        });
      }
      return res.status(200).json({ ok: true });
    }

    // POST /api/alert  -> create/update alert  body: { userId, lat, lng, stopName, detail }
    if (req.method === 'POST') {
      const { userId, lat, lng, stopName, detail } = req.body || {};
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
        sql: `INSERT INTO destination_alerts (user_id, target_stop_name, target_lat, target_lng, detail, created_at)
              VALUES (?, ?, ?, ?, ?, ?)
              ON CONFLICT(user_id) DO UPDATE SET
                target_stop_name = excluded.target_stop_name,
                target_lat = excluded.target_lat,
                target_lng = excluded.target_lng,
                detail = excluded.detail,
                created_at = excluded.created_at`,
        args: [chatId, stopName, lat, lng, detail ? String(detail) : null, Date.now()],
      });

      // Confirm in Telegram that the alert is armed and tell the user the next step
      // (share Live Location). This also proves the bot can reach them.
      const confirm =
        `✅ သတိပေးချက် သတ်မှတ်ပြီးပါပြီ!\n` +
        `"${stopName}" မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးချက် ပို့ပေးမည်။\n` +
        `👉 ဤ Bot သို့ Live Location ကို ပို့ပေးပါ (Live Location ရွေးပြီး မိမိနေရာကို အစဉ် ပေးပို့နေစေရန်)။`;
      await sendTelegram(chatId, confirm);

      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (error) {
    console.error('Alert API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
