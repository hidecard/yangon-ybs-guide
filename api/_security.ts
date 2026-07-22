import { checkRateLimit } from './_rateLimit';

export function setSecurityHeaders(res: any): void {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
}

const ALLOWED_ORIGINS = new Set(
  (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
);

export function setCORS(req: any, res: any): boolean {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.size > 0 && !ALLOWED_ORIGINS.has(origin)) {
    res.status(403).json({ error: 'Origin not allowed' });
    return false;
  }
  const allowOrigin = origin || '*';
  res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGINS.size > 0 ? allowOrigin : origin || '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
  res.setHeader('Access-Control-Max-Age', '86400');
  if (origin) res.setHeader('Vary', 'Origin');
  return true;
}

export function handlePreflight(req: any, res: any): boolean {
  if (req.method === 'OPTIONS') {
    if (!setCORS(req, res)) return true;
    return res.status(200).json({});
  }
  return false;
}

export function getClientIdentifier(req: any): string {
  const forwarded = req.headers['x-forwarded-for'];
  const ip = typeof forwarded === 'string'
    ? forwarded.split(',')[0].trim()
    : Array.isArray(forwarded)
      ? forwarded[0]
      : req.connection?.remoteAddress || req.socket?.remoteAddress || 'unknown';
  return String(ip);
}

export function getDeviceId(req: any): string {
  let deviceId = 'unknown';
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    deviceId = typeof body === 'object' && body !== null && typeof body.device_id === 'string'
      ? body.device_id
      : 'unknown';
  } catch {
    deviceId = 'unknown';
  }
  return deviceId;
}

export function checkRequestSize(req: any, maxBytes = 1024 * 100): boolean {
  const contentLength = req.headers['content-length'];
  if (contentLength && Number(contentLength) > maxBytes) {
    return false;
  }
  return true;
}

export function sanitizeInput(input: unknown, maxLength: number = 1000): string | null {
  if (input === null || input === undefined) return null;
  const str = String(input);
  const trimmed = str.trim().slice(0, maxLength);
  if (trimmed.length === 0) return null;
  if (/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/i.test(trimmed)) {
    return null;
  }
  if (/on\w+\s*=/i.test(trimmed)) {
    return null;
  }
  if (/javascript:/i.test(trimmed)) {
    return null;
  }
  if (/data:\s*text\/html/i.test(trimmed)) {
    return null;
  }
  if (/vbscript:/i.test(trimmed)) {
    return null;
  }
  if (/<img\b[^>]*on\w+\s*=/i.test(trimmed)) {
    return null;
  }
  if (/<svg\b[^>]*on\w+\s*=/i.test(trimmed)) {
    return null;
  }
  return trimmed;
}

export function sanitizeRich(input: unknown, maxLength: number = 2000): string | null {
  if (input === null || input === undefined) return null;
  const str = String(input).trim().slice(0, maxLength);
  if (str.length === 0) return null;
  const cleaned = str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
  if (/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/i.test(cleaned)) {
    return null;
  }
  return cleaned;
}

export function validateEnum(value: unknown, allowed: readonly string[], field = 'field'): string {
  const str = String(value);
  if (!allowed.includes(str)) {
    throw new Error(`Invalid ${field}. Allowed: ${allowed.join(', ')}`);
  }
  return str;
}

export async function enforceRateLimit(
  req: any,
  res: any,
  endpoint: string,
  maxRequests: number = 20,
  useDeviceId = false
): Promise<boolean> {
  const ip = getClientIdentifier(req);
  const deviceId = useDeviceId ? getDeviceId(req) : 'ip';
  const identifier = `${ip}:${deviceId}`;

  const result = await checkRateLimit(identifier, endpoint, maxRequests);

  res.setHeader('X-RateLimit-Limit', String(maxRequests));
  res.setHeader('X-RateLimit-Remaining', String(result.remaining));

  if (!result.allowed) {
    res.setHeader('Retry-After', '60');
    res.status(429).json({ error: 'Too many requests. Please try again later.' });
    return false;
  }
  return true;
}

export function jsonError(res: any, status: number, message: string): void {
  res.status(status).json({ error: message });
}

export async function verifyAdmin(req: any): Promise<boolean> {
  const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';
  if (!ADMIN_PASSWORD) return false;
  const auth = req.headers.authorization || '';
  if (auth.startsWith('Bearer ')) {
    return auth.slice(7) === ADMIN_PASSWORD;
  }
  return false;
}

export async function requireAdmin(req: any, res: any): Promise<boolean> {
  if (!(await verifyAdmin(req))) {
    jsonError(res, 401, 'Unauthorized');
    return false;
  }
  return true;
}
