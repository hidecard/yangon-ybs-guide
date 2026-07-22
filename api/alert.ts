import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  sanitizeInput,
  sanitizeRich,
  enforceRateLimit,
  jsonError,
} from './_security';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const BOT_TOKEN = process.env.BOT_TOKEN || '';

async function sendTelegram(chatId: string, text: string): Promise<boolean> {
  if (!BOT_TOKEN) {
    console.error('[alert] BOT_TOKEN is not set');
    return false;
  }
  try {
    const escapedText = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const resp = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text: escapedText }),
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
      await turso.execute(`ALTER TABLE destination_alerts ADD COLUMN detail TEXT`).catch(() => {});
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

function validateLat(value: unknown): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n < -90 || n > 90) return null;
  return n;
}

function validateLng(value: unknown): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n < -180 || n > 180) return null;
  return n;
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;

  try {
    await ensureSchema();

    if (req.method === 'GET') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      const userId = String(req.query.userId || '');
      if (!userId) return jsonError(res, 400, 'userId required');

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

    if (req.method === 'DELETE') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }
      const userId = String(req.body?.userId || '');
      if (!userId) return jsonError(res, 400, 'userId required');

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

    if (req.method === 'POST') {
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
      }

      const rate = await enforceRateLimit(req, res, 'alert', 10);
      if (!rate) return;

      const { userId, lat, lng, stopName, detail } = req.body || {};
      if (!userId || !stopName) {
        return jsonError(res, 400, 'userId, lat, lng, stopName required');
      }

      const cleanLat = validateLat(lat);
      const cleanLng = validateLng(lng);
      if (cleanLat === null || cleanLng === null) {
        return jsonError(res, 400, 'Invalid coordinates');
      }

      const cleanStopName = sanitizeInput(stopName, 200);
      if (!cleanStopName) {
        return jsonError(res, 400, 'Invalid stopName');
      }

      const cleanDetail = sanitizeRich(detail, 1000);
      const cleanUserId = sanitizeInput(userId, 100);

      const user = await turso.execute({
        sql: 'SELECT chat_id FROM telegram_users WHERE user_id = ?',
        args: [cleanUserId],
      });

      if (user.rows.length === 0) {
        return res.status(400).json({
          error: 'not_linked',
          message: 'Telegram နှင့် မချိတ်ဆက်ရသေးပါ။',
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
        args: [chatId, cleanStopName, cleanLat, cleanLng, cleanDetail, Date.now()],
      });

      const confirm =
        `✅ သတိပေးချက် သတ်မှတ်ပြီးပါပြီ!\n` +
        `"${cleanStopName}" မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးချက် ပို့ပေးမည်။\n` +
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
