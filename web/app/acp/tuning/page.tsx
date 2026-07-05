'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Flag {
  flag_key: string; flag_value: string; description: string | null;
  updated_by: number | null; updated_at: string;
}

export default function TuningPage() {
  const [flags, setFlags] = useState<Flag[]>([]);
  const [edits, setEdits] = useState<Record<string, string>>({});
  const [history, setHistory] = useState<{ key: string; rows: any[] } | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try { setFlags(await api('/v1/acp/tuning')); }
    catch (e) { setError((e as Error).message); }
  }

  useEffect(() => { void load(); }, []);

  async function save(key: string) {
    const raw = edits[key];
    if (raw === undefined) return;
    let value: unknown;
    try { value = JSON.parse(raw); }
    catch { setError(`Ungültiges JSON für ${key}`); return; }
    try {
      await api(`/v1/acp/tuning/${key}`, { method: 'PUT', body: JSON.stringify({ value }) });
      setEdits((e) => { const copy = { ...e }; delete copy[key]; return copy; });
      await load();
    } catch (e) { setError((e as Error).message); }
  }

  async function showHistory(key: string) {
    try { setHistory({ key, rows: await api(`/v1/acp/tuning/${key}/history`) }); }
    catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      <div className="panel">
        <h1 className="font-semibold text-white">Live-Tuning / Feature-Flags</h1>
        <p className="text-xs text-gray-500 mt-1">
          Änderungen greifen ohne Restart (Gameserver übernimmt binnen 60 s).
          Jede Änderung ist versioniert — Rollback = alten Wert erneut speichern.
        </p>
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}

      <div className="panel overflow-x-auto">
        <table className="w-full">
          <thead><tr>
            <th className="th">Key</th><th className="th">Wert (JSON)</th><th className="th">Geändert</th><th className="th"></th>
          </tr></thead>
          <tbody>
            {flags.map((f) => (
              <tr key={f.flag_key}>
                <td className="td font-mono text-xs whitespace-nowrap">{f.flag_key}</td>
                <td className="td">
                  <input className="input font-mono text-xs"
                    value={edits[f.flag_key] ?? f.flag_value}
                    onChange={(e) => setEdits({ ...edits, [f.flag_key]: e.target.value })} />
                </td>
                <td className="td text-xs text-gray-500 whitespace-nowrap">
                  {new Date(f.updated_at).toLocaleString('de-DE')}
                </td>
                <td className="td whitespace-nowrap space-x-1">
                  <button className="btn text-xs" onClick={() => save(f.flag_key)}
                    disabled={edits[f.flag_key] === undefined}>Speichern</button>
                  <button className="btn-ghost text-xs" onClick={() => showHistory(f.flag_key)}>Historie</button>
                </td>
              </tr>
            ))}
            {flags.length === 0 && (
              <tr><td className="td text-gray-500" colSpan={4}>
                Noch keine Flags — sie registrieren sich beim ersten Zugriff der Module selbst.
              </td></tr>
            )}
          </tbody>
        </table>
      </div>

      {history && (
        <div className="panel">
          <h2 className="font-semibold text-white mb-2 text-sm">Historie: {history.key}</h2>
          {history.rows.map((h, i) => (
            <p key={i} className="text-xs py-1 border-t border-white/5 font-mono">
              {new Date(h.changed_at).toLocaleString('de-DE')}: {h.old_value ?? 'null'} → {h.new_value}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
