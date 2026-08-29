export interface NotificationItem {
  id: number;
  title: string;
  message: string;
  type: 'info' | 'update' | 'alert';
  createdAt: number;
}

const CACHE_KEY = 'ybs_notifications_cache';
const LAST_SEEN_KEY = 'ybs_notifications_last_seen';

async function api(path: string, init?: RequestInit): Promise<any> {
  const mergedHeaders = {
    'Content-Type': 'application/json',
    ...(init?.headers || {}),
  };
  const res = await fetch(path, {
    ...init,
    headers: mergedHeaders,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export async function fetchNotifications(): Promise<NotificationItem[]> {
  try {
    const data = await api('/api/notifications?limit=50');
    return (data.notifications || []) as NotificationItem[];
  } catch {
    return [];
  }
}

export async function postNotification(n: {
  title: string;
  message: string;
  type?: 'info' | 'update' | 'alert';
  token?: string;
}): Promise<boolean> {
  try {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (n.token) headers['Authorization'] = `Bearer ${n.token}`;
    await api('/api/notifications', {
      method: 'POST',
      headers,
      body: JSON.stringify({ title: n.title, message: n.message, type: n.type }),
    });
    return true;
  } catch {
    return false;
  }
}

export function getLastSeenNotificationId(): number | null {
  try {
    const raw = localStorage.getItem(LAST_SEEN_KEY);
    return raw ? Number(raw) : null;
  } catch {
    return null;
  }
}

export function setLastSeenNotificationId(id: number): void {
  localStorage.setItem(LAST_SEEN_KEY, String(id));
}
