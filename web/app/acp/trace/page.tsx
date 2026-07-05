'use client';

import { useState } from 'react';
import { api, formatMoney } from '@/lib/api';

interface EventRow { time: string; type: string; payload: Record<string, unknown>; correlation_id: string | null }
interface Flow {
  nodes: Array<{ id: string; kind: string }>;
  edges: Array<{ from: string; to: string; total: number; count: number }>;
}

export default function TracePage() {
  const [uuid, setUuid] = useState('');
  const [trace, setTrace] = useState<EventRow[] | null>(null);
  const [charId, setCharId] = useState('');
  const [flow, setFlow] = useState<Flow | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function loadTrace() {
    setError(null);
    try { setTrace(await api(`/v1/acp/itemtrace/${uuid.trim()}`)); }
    catch (e) { setError((e as Error).message); }
  }

  async function loadFlow() {
    setError(null);
    try { setFlow(await api(`/v1/acp/moneyflow/${charId.trim()}?days=7&hops=2`)); }
    catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="space-y-6">
      {error && <p className="text-red-400 text-sm">{error}</p>}

      <div className="panel">
        <h1 className="font-semibold text-white mb-3">Item-Trace — komplette Besitzkette einer Instanz</h1>
        <div className="flex gap-2">
          <input className="input font-mono" placeholder="Item-Instanz-UUID" value={uuid}
            onChange={(e) => setUuid(e.target.value)} />
          <button className="btn" onClick={loadTrace}>Trace</button>
        </div>
        {trace && (
          <ol className="mt-4 space-y-2 border-l border-white/10 pl-4">
            {[...trace].reverse().map((e, i) => (
              <li key={i} className="text-sm">
                <span className="text-gray-500 text-xs">{new Date(e.time).toLocaleString('de-DE')}</span>{' '}
                <span className="text-white">{e.type}</span>
                <div className="text-xs font-mono text-gray-400 break-all">{JSON.stringify(e.payload)}</div>
              </li>
            ))}
            {trace.length === 0 && <p className="text-sm text-gray-500">Keine Events zu dieser UUID.</p>}
          </ol>
        )}
      </div>

      <div className="panel">
        <h1 className="font-semibold text-white mb-1">Geldfluss — woher kam Geld, wohin ging es (2 Hops, 7 Tage)</h1>
        <p className="text-xs text-gray-500 mb-3">Aggregierte Kanten; die interaktive Graph-Visualisierung folgt als Ausbaustufe.</p>
        <div className="flex gap-2">
          <input className="input" placeholder="Charakter-ID" value={charId}
            onChange={(e) => setCharId(e.target.value)} />
          <button className="btn" onClick={loadFlow}>Analysieren</button>
        </div>
        {flow && (
          <table className="w-full mt-4">
            <thead><tr>
              <th className="th">Von</th><th className="th">Nach</th>
              <th className="th">Summe</th><th className="th">Transfers</th>
            </tr></thead>
            <tbody>
              {flow.edges.sort((a, b) => b.total - a.total).map((e, i) => (
                <tr key={i}>
                  <td className="td">{e.from === 'system' ? 'System' : `Char ${e.from}`}</td>
                  <td className="td">{e.to.startsWith('company:') ? `Firma ${e.to.slice(8)}` : e.to === 'system' ? 'System' : `Char ${e.to}`}</td>
                  <td className="td">{formatMoney(e.total)}</td>
                  <td className="td">{e.count}</td>
                </tr>
              ))}
              {flow.edges.length === 0 && (
                <tr><td className="td text-gray-500" colSpan={4}>Keine Transfers im Zeitraum.</td></tr>
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
