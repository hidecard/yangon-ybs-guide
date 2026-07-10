import { createClient } from '@libsql/client';

export const dynamic = 'force-dynamic';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

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

export default async function handler(req: any, res: any) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const body = req.body;

    if (body.edited_message && body.edited_message.location) {
      const { latitude, longitude } = body.edited_message.location;
      const userId = String(body.edited_message.from.id);

      const result = await turso.execute({
        sql: 'SELECT * FROM destination_alerts WHERE user_id = ?',
        args: [userId],
      });

      if (result.rows.length > 0) {
        const alert = result.rows[0] as any;
        const targetLat = Number(alert.target_lat);
        const targetLng = Number(alert.target_lng);
        const stopName = String(alert.target_stop_name);

        const distance = getDistance(latitude, longitude, targetLat, targetLng);

        // ၅၀၀ မီတာ (၀.၅ ကီလိုမီတာ) အတွင်း ရောက်ရှိပါက
        if (distance <= 0.5) {
          const botToken = process.env.BOT_TOKEN;
          const telegramUrl = `https://api.telegram.com/bot${botToken}/sendMessage`;

          // Telegram Message ပို့ခြင်းနှင့် Turso Record ဖျက်ခြင်းကို 
          // တစ်ပြိုင်နက်တည်း အမြန်ဆုံး Run စေရန် Promise.all သုံးပါသည်
          await Promise.all([
            fetch(telegramUrl, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: userId,
                text: `📢 သတိပေးချက်: ${stopName} မှတ်တိုင်သို့ ရောက်ရှိတော့မည် ဖြစ်ပါသဖြင့် ဆင်းရန် အဆင့်သင့်ပြင်ပါဗျာ။`,
              }),
            }),
            turso.execute({
              sql: 'DELETE FROM destination_alerts WHERE user_id = ?',
              args: [userId],
            })
          ]);
        }
      }
    }

    return res.status(200).json({ status: 'ok' });
  } catch (error) {
    console.error('Webhook Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}