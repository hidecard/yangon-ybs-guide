export type BusUpdateType =
  | 'started'
  | 'reached'
  | 'road_closed'
  | 'not_running'
  | 'other';

export interface BusUpdate {
  id?: number;
  routeId: string;
  stop?: string;
  type: BusUpdateType;
  note?: string;
  lat?: number;
  lng?: number;
  userId?: string;
  createdAt?: number;
}

export const UPDATE_TYPE_META: Record<
  BusUpdateType,
  { label: string; color: string; bg: string; dot: string }
> = {
  started: {
    label: 'စထွက်ပါပြီ',
    color: 'text-emerald-700',
    bg: 'bg-emerald-50 border-emerald-200',
    dot: 'bg-emerald-500',
  },
  reached: {
    label: 'ဘယ်နား ရောက်ပါပြီ',
    color: 'text-blue-700',
    bg: 'bg-blue-50 border-blue-200',
    dot: 'bg-blue-500',
  },
  road_closed: {
    label: 'ကားလမ်းပိတ်နေ',
    color: 'text-rose-700',
    bg: 'bg-rose-50 border-rose-200',
    dot: 'bg-rose-500',
  },
  not_running: {
    label: 'ဘတ်စ်မထွက်သေး',
    color: 'text-amber-700',
    bg: 'bg-amber-50 border-amber-200',
    dot: 'bg-amber-500',
  },
  other: {
    label: 'အခြား',
    color: 'text-slate-700',
    bg: 'bg-slate-50 border-slate-200',
    dot: 'bg-slate-400',
  },
};

async function api(path: string, init?: RequestInit): Promise<any> {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export async function fetchBusUpdates(opts?: {
  routeId?: string;
  limit?: number;
}): Promise<BusUpdate[]> {
  const params = new URLSearchParams();
  if (opts?.routeId) params.set('routeId', opts.routeId);
  params.set('limit', String(opts?.limit || 50));
  const data = await api(`/api/bus-updates?${params.toString()}`);
  return (data.updates || []) as BusUpdate[];
}

export async function postBusUpdate(u: BusUpdate): Promise<boolean> {
  try {
    await api('/api/bus-updates', {
      method: 'POST',
      body: JSON.stringify(u),
    });
    return true;
  } catch {
    return false;
  }
}

export interface Prediction {
  stop: string;
  etaMinutes: number;
  distanceKm: number;
}

export async function fetchPredictions(routeId: string): Promise<{ predictions: Prediction[]; message?: string }> {
  const data = await api(`/api/predictions?routeId=${encodeURIComponent(routeId)}`);
  return data;
}

export function timeAgo(ms?: number): string {
  if (!ms) return '';
  const diff = Date.now() - ms;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'ယခု';
  if (m < 60) return `${m} မိနစ် အကြာ`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} နာရီ အကြာ`;
  const d = Math.floor(h / 24);
  return `${d} ရက် အကြာ`;
}
