import { setSecurityHeaders, handlePreflight, setCORS, jsonError, enforceRateLimit } from './_security';

interface RouteFileMeta {
  hash: string;
  version: number;
  route_id: string;
  data: any;
}

interface RouteManifest {
  global_version: number;
  generated_at: number;
  total_routes: number;
  files: Record<string, RouteFileMeta>;
}

function loadManifest(): RouteManifest {
  try {
    const fs = require('fs');
    const path = require('path');
    const manifestPath = path.join(process.cwd(), 'public', 'routes_manifest.json');
    const raw = fs.readFileSync(manifestPath, 'utf-8');
    return JSON.parse(raw) as RouteManifest;
  } catch (e) {
    console.error('Failed to load routes_manifest.json:', e);
    throw e;
  }
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res);
  if (handlePreflight(req, res)) return;
  if (!setCORS(req, res)) return;

  try {
    const action = String(req.query.action || '');

    if (action === 'delta') {
      if (req.method !== 'GET') {
        return jsonError(res, 405, 'Method Not Allowed');
      }

      if (!(await enforceRateLimit(req, res, 'routes-delta', 30))) return;

      const since = Number(req.query.since || '0');
      const manifest = loadManifest();

      const changes: any[] = [];

      for (const [filename, meta] of Object.entries(manifest.files)) {
        if (meta.version > since) {
          changes.push({
            filename,
            route_id: meta.route_id,
            data: meta.data,
          });
        }
      }

      return res.status(200).json({
        version: manifest.global_version,
        total_changes: changes.length,
        changes,
      });
    }

    if (action === 'manifest') {
      if (!(await enforceRateLimit(req, res, 'routes-manifest', 30))) return;

      const manifest = loadManifest();
      return res.status(200).json({
        version: manifest.global_version,
        total_routes: manifest.total_routes,
        files: Object.entries(manifest.files).map(([name, meta]) => ({
          filename: name,
          route_id: meta.route_id,
          version: meta.version,
          hash: meta.hash,
        })),
      });
    }

    return jsonError(res, 404, 'Not found');
  } catch (error) {
    console.error('Routes API Error:', error);
    return jsonError(res, 500, 'Internal Server Error');
  }
}
