import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  jsonError,
} from './_security';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;

  if (req.method === 'POST') {
    if (!checkRequestSize(req, 1024)) {
      return jsonError(res, 413, 'Payload too large');
    }
    const { password } = req.body || {};
    if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) {
      return jsonError(res, 401, 'Invalid password');
    }
    return res.status(200).json({ ok: true, token: ADMIN_PASSWORD });
  }

  if (req.method === 'GET') {
    if (!checkRequestSize(req, 1024)) {
      return jsonError(res, 413, 'Payload too large');
    }
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (!token || token !== ADMIN_PASSWORD) {
      return jsonError(res, 401, 'Invalid or expired session');
    }
    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method Not Allowed' });
}
