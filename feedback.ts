export type FeedbackType = 'bug' | 'wrong_info' | 'suggestion' | 'other';

export interface FeedbackItem {
  id?: number;
  type: FeedbackType;
  message: string;
  routeId?: string;
  userId?: string;
  createdAt?: number;
}

export const FEEDBACK_TYPE_META: Record<
  FeedbackType,
  { label: string; color: string; bg: string }
> = {
  bug: {
    label: 'အမှား',
    color: 'text-rose-700',
    bg: 'bg-rose-50 border-rose-200',
  },
  wrong_info: {
    label: 'မှားတဲ့ အချက်အလက်',
    color: 'text-amber-700',
    bg: 'bg-amber-50 border-amber-200',
  },
  suggestion: {
    label: 'အကြံပြုချက်',
    color: 'text-blue-700',
    bg: 'bg-blue-50 border-blue-200',
  },
  other: {
    label: 'အခြား',
    color: 'text-slate-700',
    bg: 'bg-slate-50 border-slate-200',
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

export async function postFeedback(f: FeedbackItem): Promise<boolean> {
  try {
    await api('/api/feedback', {
      method: 'POST',
      body: JSON.stringify(f),
    });
    return true;
  } catch {
    return false;
  }
}

export async function fetchFeedback(opts?: { limit?: number }): Promise<FeedbackItem[]> {
  const params = new URLSearchParams();
  if (opts?.limit) params.set('limit', String(opts.limit));
  const data = await api(`/api/feedback?${params.toString()}`);
  return (data.feedback || []) as FeedbackItem[];
}
