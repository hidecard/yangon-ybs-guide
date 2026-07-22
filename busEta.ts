export interface BusEstimate {
  stop: string;
  etaMinutes: number;
  distanceKm: number;
}

export interface BusEtaResponse {
  estimates: BusEstimate[];
  busPosition?: { lat: number; lng: number };
  nearestStop?: string;
  ageMin?: number;
  message?: string;
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

export async function fetchBusEta(routeId: string): Promise<BusEtaResponse> {
  const data = await api(`/api/bus?action=eta&routeId=${encodeURIComponent(routeId)}`);
  return data as BusEtaResponse;
}
