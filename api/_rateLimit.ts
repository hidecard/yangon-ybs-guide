import { createClient } from '@libsql/client';

const turso = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN!,
});

let schemaReady: Promise<void> | null = null;
function ensureSchema(): Promise<void> {
  if (!schemaReady) {
    schemaReady = (async () => {
      await turso.execute(`CREATE TABLE IF NOT EXISTS rate_limits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        request_count INTEGER NOT NULL DEFAULT 1,
        window_start INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )`);
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_rate_limits_lookup ON rate_limits(identifier, endpoint, window_start)`
      );
      await turso.execute(
        `CREATE INDEX IF NOT EXISTS idx_rate_limits_cleanup ON rate_limits(created_at)`
      );
    })().catch((e) => {
      schemaReady = null;
      throw e;
    });
  }
  return schemaReady;
}

const WINDOW_MS = 60 * 1000;
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000;
let cleanupTimer: ReturnType<typeof setInterval> | null = null;

function scheduleCleanup(): void {
  if (cleanupTimer) return;
  cleanupTimer = setInterval(async () => {
    try {
      const cutoff = Date.now() - 2 * WINDOW_MS;
      await turso.execute('DELETE FROM rate_limits WHERE created_at < ?', [cutoff]);
    } catch {
      schemaReady = null;
      cleanupTimer = null;
    }
  }, CLEANUP_INTERVAL_MS);
}

export async function checkRateLimit(
  identifier: string,
  endpoint: string,
  maxRequests: number
): Promise<{ allowed: boolean; remaining: number }> {
  await ensureSchema();
  scheduleCleanup();

  const now = Date.now();
  const windowStart = now - (now % WINDOW_MS);

  const existing = await turso.execute(
    'SELECT id, request_count FROM rate_limits WHERE identifier = ? AND endpoint = ? AND window_start = ?',
    [identifier, endpoint, windowStart]
  );

  if (existing.rows.length > 0) {
    const row = existing.rows[0] as any;
    const current = Number(row.request_count) + 1;
    if (current > maxRequests) {
      return { allowed: false, remaining: Math.max(0, maxRequests - Number(row.request_count)) };
    }
    await turso.execute(
      'UPDATE rate_limits SET request_count = ? WHERE id = ?',
      [current, Number(row.id)]
    );
    return { allowed: true, remaining: maxRequests - current };
  }

  await turso.execute(
    'INSERT INTO rate_limits (identifier, endpoint, request_count, window_start, created_at) VALUES (?, ?, 1, ?, ?)',
    [identifier, endpoint, windowStart, now]
  );

  return { allowed: true, remaining: maxRequests - 1 };
}
