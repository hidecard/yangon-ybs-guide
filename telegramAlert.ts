// Frontend helper for the Telegram destination-alert feature.
// Flow: generate a local userId -> deep-link the bot with /start <userId> so the
// webhook links the Telegram chat -> call /api/alert to store the target stop in Turso.

const STORAGE_KEY = 'ybs_telegram_user_id';
export const TELEGRAM_BOT = 'ybsguide_bot';

// Short, Telegram-deep-link-safe (A-Z, 2-9, no confusing chars), easy to type.
function randomCode(len: number): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < len; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

export function getUserId(): string {
  try {
    let id = localStorage.getItem(STORAGE_KEY);
    if (!id) {
      id = randomCode(8);
      localStorage.setItem(STORAGE_KEY, id);
    }
    return id;
  } catch {
    return 'ANON' + randomCode(4);
  }
}

export function connectUrl(userId: string): string {
  return `https://t.me/${TELEGRAM_BOT}?start=${userId}`;
}

export interface AlertStatus {
  linked: boolean;
  alert: { stopName: string } | null;
}

async function api(path: string, init?: RequestInit): Promise<any> {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err: any = new Error(data.message || data.error || 'Request failed');
    err.code = data.error;
    throw err;
  }
  return data;
}

export async function getAlertStatus(userId: string): Promise<AlertStatus> {
  return api(`/api/alert?userId=${encodeURIComponent(userId)}`);
}

export async function setAlert(
  userId: string,
  stop: { name_mm: string; lat: number; lng: number }
): Promise<void> {
  await api('/api/alert', {
    method: 'POST',
    body: JSON.stringify({
      userId,
      lat: stop.lat,
      lng: stop.lng,
      stopName: stop.name_mm,
    }),
  });
}

export async function cancelAlert(userId: string): Promise<void> {
  await api('/api/alert', {
    method: 'DELETE',
    body: JSON.stringify({ userId }),
  });
}
