const STORAGE_KEY = 'ybs_trip_history';

export interface TripHistoryItem {
  id: string;
  type: 'search' | 'stop' | 'route';
  label: string;
  subtitle?: string;
  routeId?: string;
  timestamp: number;
}

const MAX_ITEMS = 20;

export function getTripHistory(): TripHistoryItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as TripHistoryItem[];
  } catch {
    return [];
  }
}

export function addTripHistory(item: Omit<TripHistoryItem, 'id' | 'timestamp'>): TripHistoryItem[] {
  const history = getTripHistory();
  const newItem: TripHistoryItem = {
    ...item,
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    timestamp: Date.now(),
  };
  history.unshift(newItem);
  const trimmed = history.slice(0, MAX_ITEMS);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(trimmed));
  return trimmed;
}

export function removeTripHistoryItem(id: string): TripHistoryItem[] {
  const history = getTripHistory();
  const filtered = history.filter(item => item.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(filtered));
  return filtered;
}

export function clearTripHistory(): void {
  localStorage.removeItem(STORAGE_KEY);
}
