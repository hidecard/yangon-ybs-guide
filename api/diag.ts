const BOT_TOKEN = process.env.BOT_TOKEN!;

export default async function handler(req: any, res: any) {
  // Diagnostic only. Open: /api/diag?chat=<your telegram chat id>
  // To get your chat id, message @userinfobot or @RawDataBot on Telegram.
  const chat = String(req.query.chat || '');

  const tokenSet = !!BOT_TOKEN;
  let sendResult: any = 'skipped (no chat id provided)';

  if (chat) {
    try {
      const resp = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chat,
          text: '🔧 Diagnostic test from YBS webhook. If you see this, sending works!',
        }),
      });
      sendResult = await resp.json();
    } catch (e: any) {
      sendResult = { error: String(e?.message || e) };
    }
  }

  return res.status(200).json({
    botTokenSet: tokenSet,
    botTokenPreview: BOT_TOKEN ? BOT_TOKEN.slice(0, 6) + '…' + BOT_TOKEN.slice(-4) : null,
    sendResult,
  });
}
