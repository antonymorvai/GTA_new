'use client';

import { useState } from 'react';
import { api } from '@/lib/api';

interface LogRow {
  time: string; event_id: string; type: string;
  actor_account: number | null; actor_character: number | null;
  target_kind: string | null; target_id: string | null;
  correlation_id: string | null; payload: Record<string, unknown>;
}

export default function LogsPage() {
  const [filters, setFilters] = useState({ type: '', actorCharacter: '', targetId: '', text: '', correlationId: '' });
  const [rows, setRows] = useState<LogRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function search(correlationOverride?: string) {
    setBusy(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      if (correlationOverride) {
        params.set('correlationId', correlationOverride);
      } else {
        if (filters.type) params.set('type', filters.type);
        if (filters.actorCharacter) params.set('actorCharacter', filters.actorCharacter);
        if (filters.targetId) params.set('targetId', filters.targetId);
        if (filters.text) params.set('text', filters.text);
        if (filters.correlationId) params.set('correlationId', filters.correlationId);
      }
      params.set('limit', '100');
      setRows(await api<LogRow[]>(`/v1/acp/logs?${params.toString()}`));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="panel">
        <h1 className="font-semibold text-white mb-3">Log-Explorer</h1>
        <div className="grid grid-cols-5 gap-2">
          <input className="input" placeholder="Typ (z. B. money.)" value={filters.type}
            onChange={(e) => setFilters({ ...filters, type: e.target.value })} />
          <input className="input" placeholder="Charakter-ID" value={filters.actorCharacter}
            onChange={(e) => setFilters({ ...filters, actorCharacter: e.target.value })} />
          <input className="input" placeholder="Target-ID" value={filters.targetId}
            onChange={(e) => setFilters({ ...filters, targetId: e.target.value })} />
          <input className="input" placeholder="Volltext (Payload)" value={filters.text}
            onChange={(e) => setFilters({ ...filters, text: e.target.value })} />
          <button className="btn" onClick={() => search()} disabled={busy}>Suchen</button>
        </div>
        {error && <p className="text-sm text-red-400 mt-2">{error}</p>}
      </div>

      <div className="panel overflow-x-auto">
        <table className="w-full">
          <thead><tr>
            <th className="th">Zeit</th><th className="th">Typ</th><th className="th">Akteur</th>
            <th className="th">Ziel</th><th className="th">Korrelation</th><th className="th">Payload</th>
          </tr></thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.event_id}>
                <td className="td whitespace-nowrap">{new Date(r.time).toLocaleString('de-DE')}</td>
                <td className="td">{r.type}</td>
                <td className="td text-xs">
                  {r.actor_character ? `Char ${r.actor_character}` : r.actor_account ? `Acc ${r.actor_account}` : 'System'}
                </td>
                <td className="td text-xs">{r.target_kind ? `${r.target_kind}:${r.target_id}` : '—'}</td>
                <td className="td text-xs">
                  {r.correlation_id ? (
                    <button className="text-accent hover:underline"
                      onClick={() => search(r.correlation_id!)}>
                      {r.correlation_id.slice(0, 8)}…
                    </button>
                  ) : '—'}
                </td>
                <td className="td text-xs font-mono text-gray-400 max-w-md break-all">
                  {JSON.stringify(r.payload)}
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr><td className="td text-gray-500" colSpan={6}>Keine Ergebnisse — Filter setzen und suchen.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
