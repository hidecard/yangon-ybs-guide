export interface SharedTrip {
  shareToken: string;
  userId: string;
  userName: string;
  routeId: string;
  routeLabel: string;
  nextStopIndex: number;
  destinationStopName: string;
  status: 'EN_ROUTE' | 'ARRIVED';
  lat?: number | null;
  lng?: number | null;
  updatedAt: number;
}

export interface CreateSharedTripInput {
  userId: string;
  userName: string;
  routeId: string;
  routeLabel: string;
  nextStopIndex: number;
  destinationStopName: string;
  status?: 'EN_ROUTE' | 'ARRIVED';
  lat?: number;
  lng?: number;
}

async function api(path: string, init?: RequestInit): Promise<any> {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export async function createSharedTrip(input: CreateSharedTripInput): Promise<SharedTrip | null> {
  try {
    const data = await api('/api/shared-trips', {
      method: 'POST',
      body: JSON.stringify(input),
    });
    return data.shareToken ? { ...input, shareToken: data.shareToken, updatedAt: Date.now(), status: input.status || 'EN_ROUTE' } : null;
  } catch {
    return null;
  }
}

export async function fetchSharedTrip(token: string): Promise<SharedTrip | null> {
  try {
    const data = await api(`/api/shared-trips?token=${encodeURIComponent(token)}`);
    return data as SharedTrip;
  } catch {
    return null;
  }
}

export async function updateSharedTrip(token: string, patch: { nextStopIndex?: number; status?: 'EN_ROUTE' | 'ARRIVED'; lat?: number; lng?: number }): Promise<boolean> {
  try {
    await api('/api/shared-trips', {
      method: 'PATCH',
      body: JSON.stringify({ token, ...patch }),
    });
    return true;
  } catch {
    return false;
  }
}

export function getShareUrl(token: string): string {
  if (typeof window === 'undefined') return `https://ybs-mm-v2.vercel.app/shared-trip/${token}`;
  return `${window.location.origin}/shared-trip/${token}`;
}
