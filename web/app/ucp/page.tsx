'use client';

import { useEffect, useState } from 'react';
import { api, formatMoney, hasToken } from '@/lib/api';
import { useRouter } from 'next/navigation';

interface Character {
  id: number; slot: number; first_name: string; last_name: string;
  state: string; played_minutes: number; cash: number; bank: number;
  account_number: string | null;
}

interface Dashboard {
  account: { username: string; whitelist_status: string; totp_enabled: number };
  characters: Character[];
}

export default function UcpPage() {
  const router = useRouter();
  const [data, setData] = useState<Dashboard | null>(null);
  const [statement, setStatement] = useState<Array<{ time: string; type: string; payload: Record<string, unknown> }> | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!hasToken()) {
      router.push('/login');
      return;
    }
    api<Dashboard>('/v1/ucp/dashboard').then(setData).catch((e) => setError(e.message));
  }, [router]);

  async function loadStatement(characterId: number) {
    try {
      setStatement(await api(`/v1/ucp/characters/${characterId}/statement`));
    } catch (e) {
      setError((e as Error).message);
    }
  }

  if (error) return <p className="text-red-400">{error}</p>;
  if (!data) return <p className="text-gray-400">Lade …</p>;

  const wl: Record<string, string> = {
    none: 'Keine Bewerbung', pending: 'Bewerbung in Prüfung',
    approved: 'Freigeschaltet', rejected: 'Abgelehnt',
  };

  return (
    <div className="space-y-6">
      <div className="panel">
        <h1 className="text-xl font-semibold text-white">Willkommen, {data.account.username}</h1>
        <p className="text-sm text-gray-400 mt-1">
          Whitelist: <span className="text-white">{wl[data.account.whitelist_status] ?? data.account.whitelist_status}</span>
          {' · '}2FA: <span className="text-white">{data.account.totp_enabled ? 'aktiv' : 'nicht aktiv'}</span>
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {data.characters.map((c) => (
          <div key={c.id} className="panel">
            <h2 className="font-semibold text-white">{c.first_name} {c.last_name}</h2>
            <p className="text-xs text-gray-500">Slot {c.slot} · {c.state} · {Math.floor(c.played_minutes / 60)} h</p>
            <p className="text-sm mt-2">Bar: {formatMoney(c.cash)}<br />
              Bank: {formatMoney(c.bank)} {c.account_number && <span className="text-gray-500">({c.account_number})</span>}</p>
            <button className="btn-ghost mt-3 text-xs" onClick={() => loadStatement(c.id)}>
              Kontoauszug
            </button>
          </div>
        ))}
        {data.characters.length === 0 && (
          <p className="text-gray-400 text-sm">Noch keine Charaktere — erstelle deinen ersten auf dem Server.</p>
        )}
      </div>

      {statement && (
        <div className="panel overflow-x-auto">
          <h2 className="font-semibold text-white mb-3">Kontoauszug (letzte 100 Buchungen)</h2>
          <table className="w-full">
            <thead><tr><th className="th">Zeit</th><th className="th">Vorgang</th><th className="th">Details</th></tr></thead>
            <tbody>
              {statement.map((row, i) => (
                <tr key={i}>
                  <td className="td whitespace-nowrap">{new Date(row.time).toLocaleString('de-DE')}</td>
                  <td className="td">{row.type}</td>
                  <td className="td text-gray-400 text-xs font-mono">{JSON.stringify(row.payload)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
