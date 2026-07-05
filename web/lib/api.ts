'use client';

/** Fetch-Helfer: hängt das JWT an und wirft bei Fehlern eine lesbare Meldung. */
export async function api<T = unknown>(path: string, options: RequestInit = {}): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('hrp_token') : null;
  const res = await fetch(`/api${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
  });
  if (!res.ok) {
    let message = `Fehler ${res.status}`;
    try {
      const body = await res.json();
      message = typeof body.message === 'string' ? body.message : JSON.stringify(body.message ?? message);
    } catch {
      /* keep default */
    }
    throw new Error(message);
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

export function setToken(token: string): void {
  localStorage.setItem('hrp_token', token);
}

export function clearToken(): void {
  localStorage.removeItem('hrp_token');
}

export function hasToken(): boolean {
  return typeof window !== 'undefined' && localStorage.getItem('hrp_token') !== null;
}

export function formatMoney(cents: number | string | null | undefined): string {
  const value = Number(cents ?? 0) / 100;
  return value.toLocaleString('de-DE', { minimumFractionDigits: 2 }) + ' $';
}
