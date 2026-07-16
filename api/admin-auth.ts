import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = 'hidecard969aky';

export default async function handler(req: any, res: any) {
  if (req.method === 'POST') {
    const { password } = req.body || {};
    if (password === ADMIN_PASSWORD) {
      return res.status(200).json({ ok: true });
    }
    return res.status(401).json({ error: 'Invalid password' });
  }

  return res.status(405).json({ error: 'Method Not Allowed' });
}
