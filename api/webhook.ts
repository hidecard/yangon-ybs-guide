import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const BOT_TOKEN = process.env.BOT_TOKEN!;

const ALERT_RADIUS_KM = 0.5; // 500 meters

// Haversine distance in kilometers
function getDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Schema is created once per lambda warm instance
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

async function sendTelegram(chatId: string, text: string): Promise<void> {
  await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' }),
  });
}

async function linkUser(payload: string, chatId: string, from: any): Promise<void> {
  await turso.execute({
    sql: `INSERT INTO telegram_users (user_id, chat_id, username, first_name, linked_at)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET chat_id = excluded.chat_id, linked_at = excluded.linked_at`,
    args: [payload, chatId, from.username ?? null, from.first_name ?? null, Date.now()],
  });
  await sendTelegram(
    chatId,
    '✅ ချိတ်ဆက်ပြီးပါပြီ! YBS Guide နဲ့ သင့် Telegram အကောင့် ချိတ်ဆက်သွားပါပြီ။\n\n' +
    'ယခု App ထဲမှ ဆင်းမည့်မှတ်တိုင်ကို ရွေးပြီး "သတိပေးပါ" ကို နှိပ်ပါ။ ထို့နောက် ဤ Bot သို့ Live Location ပို့ပေးပါက ၅၀၀ မီတာအတွင်း ရောက်လျှင် သတိပေးချက် ပို့ပေးမည်ဖြစ်ပါသည်။'
  );
}

async function checkProximity(chatId: string, lat: number, lng: number): Promise<void> {
  const result = await turso.execute({
    sql: 'SELECT * FROM destination_alerts WHERE chat_id = ?',
    args: [chatId],
  });

  if (result.rows.length === 0) return;

  const alert = result.rows[0] as any;
  const distance = getDistance(lat, lng, Number(alert.target_lat), Number(alert.target_lng));

  if (distance <= ALERT_RADIUS_KM) {
    await Promise.all([
      sendTelegram(
        chatId,
        `📢 သတိပေးချက်: <b>${String(alert.target_stop_name)}</b> မှတ်တိုင်သို့ ရောက်ရှိတော့မည် ဖြစ်ပါသဖြင့် ဆင်းရန် အဆင့်သင့်ပြင်ပါဗျာ။`
      ),
      turso.execute({
        sql: 'DELETE FROM destination_alerts WHERE chat_id = ?',
        args: [chatId],
      }),
    ]);
  }
}

export default async function handler(req: any, res: any) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    await ensureSchema();
    const update = req.body;

    // --- Regular message (commands, first live-location share) ---
    if (update.message) {
      const msg = update.message;
      const chatId = String(msg.chat.id);
      const from = msg.from || {};

      if (msg.text) {
        const text: string = msg.text;

        if (text.startsWith('/start')) {
          const payload = text.split(' ')[1];
          if (payload) {
            await linkUser(payload, chatId, from);
            return res.status(200).json({ status: 'ok' });
          }
          // /start with no payload: guide the user to link with their code
          await sendTelegram(
            chatId,
            '👋 မင်္ဂလာပါ! ကျွန်ုပ်သည် YBS Guide Bot ဖြစ်ပါသည်။\n\n' +
            'မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် App ထဲမှ သင့် Telegram ကို ချိတ်ဆက်ပါ။\n' +
            'App ၏ "သတိပေးချက်" အပိုင်းတွင် ပြထားသော ကုဒ်ကို ဤ Bot သို့ တိုက်ရိုက် ပို့ပါ (သို့မဟုတ် /start <ကုဒ်>)။'
          );
          return res.status(200).json({ status: 'ok' });
        }

        // Bare linking code pasted directly into the chat (e.g. already-started users)
        if (/^[A-HJ-NP-Z2-9]{6,12}$/.test(text.trim())) {
          await linkUser(text.trim(), chatId, from);
          return res.status(200).json({ status: 'ok' });
        }

        if (text.startsWith('/cancel') || text.startsWith('/stop')) {
          await turso.execute({
            sql: 'DELETE FROM destination_alerts WHERE chat_id = ?',
            args: [chatId],
          });
          await sendTelegram(chatId, '🚫 သတိပေးချက်ကို ပယ်ဖျက်ပြီးပါပြီ။');
          return res.status(200).json({ status: 'ok' });
        }

        if (text.startsWith('/status')) {
          const r = await turso.execute({
            sql: 'SELECT * FROM destination_alerts WHERE chat_id = ?',
            args: [chatId],
          });
          if (r.rows.length > 0) {
            await sendTelegram(chatId, `📍 လက်ရှိ သတိပေးထားသော မှတ်တိုင်: ${String((r.rows[0] as any).target_stop_name)}`);
          } else {
            await sendTelegram(chatId, 'ℹ️ သတိပေးထားသော မှတ်တိုင် မရှိသေးပါ။');
          }
          return res.status(200).json({ status: 'ok' });
        }

        if (text.startsWith('/help')) {
          await sendTelegram(
            chatId,
            '🆘 လမ်းညွှန်:\n' +
            '• App မှ Telegram ကို ချိတ်ဆက်ပါ\n' +
            '• ဆင်းမည့်မှတ်တိုင်၌ "သတိပေးပါ" နှိပ်ပါ\n' +
            '• ဤ Bot သို့ Live Location ပို့ပါ\n' +
            '• /cancel — သတိပေးချက် ပယ်ဖျက်ရန်\n' +
            '• /status — လက်ရှိအခြေအနေ ကြည့်ရန်'
          );
          return res.status(200).json({ status: 'ok' });
        }
      }

      // First live-location share arrives as a normal message with location
      if (msg.location) {
        await checkProximity(chatId, msg.location.latitude, msg.location.longitude);
        return res.status(200).json({ status: 'ok' });
      }
    }

    // --- Live location updates arrive as edited_message ---
    if (update.edited_message && update.edited_message.location) {
      const loc = update.edited_message.location;
      const chatId = String(update.edited_message.chat.id);
      await checkProximity(chatId, loc.latitude, loc.longitude);
    }

    // Always respond 200 quickly so Telegram does not retry
    return res.status(200).json({ status: 'ok' });
  } catch (error) {
    console.error('Webhook Error:', error);
    // Still return 200 to avoid Telegram retry storms on transient errors
    return res.status(200).json({ status: 'error', message: 'internal' });
  }
}
