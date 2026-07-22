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

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS bus_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        stop TEXT,
        type TEXT NOT NULL,
        note TEXT,
        lat REAL,
        lng REAL,
        user_id TEXT,
        created_at INTEGER NOT NULL
      )`);
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

const AVG_BUS_SPEED_KMH = 15;

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

function findNearestStop(lat: number, lng: number, stops: { lat: number; lng: number; name_mm: string }[]): { index: number; distance: number } | null {
  if (!stops.length) return null;
  let best = { index: 0, distance: Infinity };
  stops.forEach((s, i) => {
    const d = getDistance(lat, lng, s.lat, s.lng);
    if (d < best.distance) best = { index: i, distance: d };
  });
  return best.distance <= 1.5 ? best : null;
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;

  try {
    await ensureSchema();

    if (!checkRequestSize(req, 1024)) {
      return jsonError(res, 413, 'Payload too large');
    }

    if (req.method !== 'GET') {
      return jsonError(res, 405, 'Method Not Allowed');
    }

    const routeId = String(req.query.routeId || '');
    if (!routeId) {
      return jsonError(res, 400, 'routeId required');
    }

    const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
    await turso.execute('DELETE FROM bus_updates WHERE created_at < ?', [oneDayAgo]);

    const recent = await turso.execute({
      sql: 'SELECT stop, type, lat, lng, created_at FROM bus_updates WHERE route_id = ? ORDER BY created_at DESC LIMIT 1',
      args: [routeId],
    });

    if (recent.rows.length === 0) {
      return res.status(200).json({ predictions: [], message: 'No recent reports for this route' });
    }

    const last = recent.rows[0] as any;
    const now = Date.now();
    const ageMin = (now - Number(last.created_at)) / 60000;
    if (ageMin > 120) {
      return res.status(200).json({ predictions: [], message: 'Last report is too old to predict' });
    }

    const stopsRaw = await import('../data_constants.ts').then(m => m.loadStopsFromRouteFiles()).then(() => {
      return import('../data_constants.ts').then(m => m.loadRoutesFromFiles()).then(routes => {
        const route = routes.find((r: any) => r.id === routeId);
        return (route?.stopsDetailed || []).map((s: any) => ({ lat: s.lat, lng: s.lng, name_mm: s.name_mm }));
      });
    }).catch(() => []);

    if (!stopsRaw.length) {
      return res.status(200).json({ predictions: [], message: 'Route stops not available' });
    }

    let currentIndex = -1;
    if (last.stop) {
      currentIndex = stopsRaw.findIndex((s: any) => s.name_mm === String(last.stop));
    }
    if (currentIndex < 0 && typeof last.lat === 'number' && typeof last.lng === 'number') {
      const found = findNearestStop(last.lat, last.lng, stopsRaw);
      if (found) currentIndex = found.index;
    }

    if (currentIndex < 0) {
      return res.status(200).json({ predictions: [], message: 'Cannot determine bus position' });
    }

    const predictions = [];
    let cumulativeMinutes = 0;
    for (let i = currentIndex + 1; i < stopsRaw.length && predictions.length < 5; i++) {
      const prev = stopsRaw[i - 1];
      const next = stopsRaw[i];
      const dist = getDistance(prev.lat, prev.lng, next.lat, next.lng);
      cumulativeMinutes += (dist / AVG_BUS_SPEED_KMH) * 60;
      predictions.push({
        stop: next.name_mm,
        etaMinutes: Math.round(cumulativeMinutes),
        distanceKm: Math.round(dist * 100) / 100,
      });
    }

    return res.status(200).json({
      predictions,
      lastUpdateAgeMin: Math.round(ageMin),
      lastStop: stopsRaw[currentIndex].name_mm,
    });
  } catch (error) {
    console.error('Predictions API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
