import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  jsonError,
  setCORS,
  requireAdmin,
} from './_security';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

const EXPORT_TABLES = [
  'rate_limits',
  'feedback',
  'telegram_users',
  'destination_alerts',
  'bus_updates',
  'notifications',
  'leaderboard_users',
  'points_history',
  'rewards',
  'redemptions',
  'update_votes',
];

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    if (req.method !== 'GET') {
      return jsonError(res, 405, 'Method Not Allowed');
    }

    if (!checkRequestSize(req, 1024)) {
      return jsonError(res, 413, 'Payload too large');
    }

    if (!(await requireAdmin(req, res))) return;

    const exportData: Record<string, any[]> = {};
    for (const table of EXPORT_TABLES) {
      try {
        const result = await turso.execute(`SELECT * FROM ${table}`);
        exportData[table] = result.rows;
      } catch {
        exportData[table] = [];
      }
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="turso-export-${timestamp}.json"`);
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json(exportData);
  } catch (error) {
    console.error('Export API Error:', error);
    return jsonError(res, 500, 'Internal Server Error');
  }
}
