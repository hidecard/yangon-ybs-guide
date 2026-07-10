// Frontend helper for the Telegram destination-alert feature.
// Flow: generate a local userId -> deep-link the bot with /start <userId> so the
// webhook links the Telegram chat -> call /api/alert to store the target stop in Turso.

const STORAGE_KEY = 'ybs_telegram_user_id';
export const TELEGRAM_BOT = 'ybsguide_bot';

export function getUserId(): string {
  try {
    let id = localStorage.getItem(STORAGE_KEY);
    if (!id) {
      id = 'u' + Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
      localStorage.setItem(STORAGE_KEY, id);
    }
    return id;
  } catch {
    return 'anonymous';
  }
}

export function connectUrl(userId: string): string {
  return `https://t.me/${TELEGRAM_BOT}?start=${encodeURIComponent(userId)}`;
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
