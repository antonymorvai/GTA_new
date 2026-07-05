'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Anomaly {
  id: number; created_at: string; rule: string;
  subject_kind: string; subject_id: string;
  detail: Record<string, unknown>; status: string;
  assigned_to: number | null; resolution: string | null;
}

const RULE_LABELS: Record<string, string> = {
  money_created_24h: 'Ungewöhnlicher Geldzuwachs (24 h)',
  admin_give_spike: 'Auffällig viele Admin-Vergaben (24 h)',
  drug_volume_24h: 'Drogenumsatz-Ausreißer (24 h)',
};

export default function AnomaliesPage() {
  const [rows, setRows] = useState<Anomaly[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try { setRows(await api('/v1/acp/anomalies')); }
    catch (e) { setError((e as Error).message); }
  }

  useEffect(() => { void load(); }, []);

  async function scan() {
    try {
      const res = await api<{ found: number }>('/v1/acp/anomalies/scan', { method: 'POST' });
      alert(`${res.found} neue Anomalie(n) gefunden.`);
      await load();
    } catch (e) { setError((e as Error).message); }
  }

  async function update(id: number, status: string) {
    const resolution = status === 'resolved' || status === 'dismissed'
      ? prompt('Begründung / Ergebnis (Pflicht):') : null;
    if ((status === 'resolved' || status === 'dismissed') && !resolution) return;
    try {
      await api(`/v1/acp/anomalies/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status, resolution }),
      });
      await load();
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      <div className="panel flex items-center justify-between">
        <h1 className="font-semibold text-white">Anomalie-Prüf-Queue</h1>
        <button className="btn" onClick={scan}>Jetzt scannen</button>
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}

      <div className="panel overflow-x-auto">
        <table className="w-full">
          <thead><tr>
            <th className="th">Zeit</th><th className="th">Regel</th><th className="th">Subjekt</th>
            <th className="th">Detail</th><th className="th">Status</th><th className="th">Aktion</th>
          </tr></thead>
          <tbody>
            {rows.map((a) => (
              <tr key={a.id}>
                <td className="td whitespace-nowrap text-xs">{new Date(a.created_at).toLocaleString('de-DE')}</td>
                <td className="td text-sm">{RULE_LABELS[a.rule] ?? a.rule}</td>
                <td className="td text-sm">
                  {a.subject_kind} {a.subject_id}
                  <a className="text-accent text-xs ml-2 hover:underline"
                    href={`/acp/logs?${a.subject_kind === 'character' ? 'actorCharacter' : 'actorAccount'}=${a.subject_id}`}>
                    Timeline →
                  </a>
                </td>
                <td className="td text-xs font-mono text-gray-400">{JSON.stringify(a.detail)}</td>
                <td className="td text-sm">{a.status}{a.resolution && <span className="block text-xs text-gray-500">{a.resolution}</span>}</td>
                <td className="td space-x-1 whitespace-nowrap">
                  {a.status === 'open' && (
                    <button className="btn-ghost text-xs" onClick={() => update(a.id, 'assigned')}>Übernehmen</button>
                  )}
                  {a.status !== 'resolved' && a.status !== 'dismissed' && (
                    <>
                      <button className="btn-ghost text-xs" onClick={() => update(a.id, 'resolved')}>Erledigt</button>
                      <button className="btn-ghost text-xs" onClick={() => update(a.id, 'dismissed')}>Verwerfen</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr><td className="td text-gray-500" colSpan={6}>Queue ist leer.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
