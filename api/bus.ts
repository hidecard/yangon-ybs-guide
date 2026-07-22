import { createClient } from '@libsql/client';
import {
  setSecurityHeaders,
  handlePreflight,
  checkRequestSize,
  jsonError,
  setCORS,
  enforceRateLimit,
  sanitizeInput,
  sanitizeRich,
  validateEnum,
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
  if (!setCORS(req, res)) return;

  try {
    const action = String(req.query.action || '');

    if (action === 'eta') {
      if (req.method !== 'GET') {
        return jsonError(res, 405, 'Method Not Allowed');
      }
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
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
    }

    if (action === 'predictions') {
      if (req.method !== 'GET') {
        return jsonError(res, 405, 'Method Not Allowed');
      }
      if (!checkRequestSize(req, 1024)) {
        return jsonError(res, 413, 'Payload too large');
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
        let best = { index: 0, distance: Infinity };
        stopsRaw.forEach((s, i) => {
          const d = getDistance(last.lat, last.lng, s.lat, s.lng);
          if (d < best.distance) best = { index: i, distance: d };
        });
        if (best.distance <= 1.5) currentIndex = best.index;
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
    }

    return jsonError(res, 404, 'Not found');
  } catch (error) {
    console.error('Bus API Error:', error);
    return jsonError(res, 500, 'Internal Server Error');
  }
}
