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

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;

  try {
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

    const updates = await turso.execute({
      sql: 'SELECT stop, type, lat, lng, created_at FROM bus_updates WHERE route_id = ? AND lat IS NOT NULL AND lng IS NOT NULL ORDER BY created_at DESC LIMIT 5',
      args: [routeId],
    });

    if (updates.rows.length === 0) {
      return res.status(200).json({ estimates: [], message: 'No live bus data available' });
    }

    const rows = updates.rows as any[];
    const latest = rows[0];
    const busLat = Number(latest.lat);
    const busLng = Number(latest.lng);
    const ageMin = Math.round((Date.now() - Number(latest.created_at)) / 60000);

    let routeStops: Array<{ name_mm: string; lat: number; lng: number }> = [];
    try {
      const routesModule = await import('../data_constants.ts');
      const routes = await routesModule.loadRoutesFromFiles();
      const route = routes.find((r: any) => r.id === routeId);
      if (route && route.stopsDetailed) {
        routeStops = route.stopsDetailed.map((s: any) => ({ name_mm: s.name_mm, lat: s.lat, lng: s.lng }));
      }
    } catch {
      return res.status(200).json({ estimates: [], message: 'Route data not available' });
    }

    if (routeStops.length === 0) {
      return res.status(200).json({ estimates: [], message: 'No stops found for route' });
    }

    let nearestIdx = -1;
    let bestDist = Infinity;
    routeStops.forEach((s, i) => {
      const d = getDistance(busLat, busLng, s.lat, s.lng);
      if (d < bestDist) {
        bestDist = d;
        nearestIdx = i;
      }
    });

    if (nearestIdx < 0) {
      return res.status(200).json({ estimates: [], message: 'Cannot determine bus position' });
    }

    const estimates = [];
    let cumulativeMinutes = 0;
    for (let i = nearestIdx + 1; i < routeStops.length && estimates.length < 8; i++) {
      const prev = routeStops[i - 1];
      const next = routeStops[i];
      const dist = getDistance(prev.lat, prev.lng, next.lat, next.lng);
      cumulativeMinutes += (dist / AVG_BUS_SPEED_KMH) * 60;
      estimates.push({
        stop: next.name_mm,
        etaMinutes: Math.round(cumulativeMinutes),
        distanceKm: Math.round(dist * 100) / 100,
      });
    }

    return res.status(200).json({
      estimates,
      busPosition: { lat: busLat, lng: busLng },
      nearestStop: routeStops[nearestIdx].name_mm,
      ageMin,
      message: latest.note || undefined,
    });
  } catch (error) {
    console.error('Bus ETA API Error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
