'use client';

import { useState } from 'react';
import { api, formatMoney } from '@/lib/api';

interface SearchRow {
  account_id: number; username: string; whitelist_status: string;
  character_id: number | null; first_name: string | null; last_name: string | null;
}

export default function PlayersPage() {
  const [q, setQ] = useState('');
  const [results, setResults] = useState<SearchRow[]>([]);
  const [file, setFile] = useState<Record<string, any> | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function search() {
    setError(null);
    try {
      setResults(await api<SearchRow[]>(`/v1/acp/players?q=${encodeURIComponent(q)}`));
    } catch (e) { setError((e as Error).message); }
  }

  async function open(accountId: number) {
    setError(null);
    try {
      setFile(await api(`/v1/acp/players/${accountId}`));
    } catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      <div className="panel flex gap-2">
        <input className="input" placeholder="Benutzername oder Charaktername" value={q}
          onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && search()} />
        <button className="btn" onClick={search}>Suchen</button>
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}

      {results.length > 0 && !file && (
        <div className="panel">
          {results.map((r, i) => (
            <button key={i} onClick={() => open(r.account_id)}
              className="block w-full text-left px-3 py-2 hover:bg-white/5 rounded text-sm">
              <span className="text-white">{r.username}</span>
              {r.first_name && <span className="text-gray-400"> · {r.first_name} {r.last_name}</span>}
              <span className="text-gray-600"> · {r.whitelist_status}</span>
            </button>
          ))}
        </div>
      )}

      {file && (
        <div className="space-y-4">
          <button className="btn-ghost text-xs" onClick={() => setFile(null)}>← Zurück zur Suche</button>
          <div className="panel">
            <h2 className="font-semibold text-white">
              360°-Akte: {file.account.username} (Account {file.account.id})
            </h2>
            <p className="text-xs text-gray-400 mt-1">
              Whitelist: {file.account.whitelist_status} · Rollen: {file.roles.join(', ') || 'player'} ·
              2FA: {file.account.totp_enabled ? 'ja' : 'nein'} · Letzter Login: {file.account.last_login_at ?? '—'}
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div className="panel">
              <h3 className="font-semibold text-white mb-2 text-sm">Charaktere</h3>
              {file.characters.map((c: any) => (
                <p key={c.id} className="text-sm py-1 border-t border-white/5">
                  #{c.id} {c.first_name} {c.last_name} · {c.state} ·
                  Bar {formatMoney(c.cash)} · Bank {formatMoney(c.bank)}
                  <a className="text-accent text-xs ml-2 hover:underline"
                    href={`/acp/logs?actorCharacter=${c.id}`}>Timeline →</a>
                </p>
              ))}
            </div>
            <div className="panel">
              <h3 className="font-semibold text-white mb-2 text-sm">Identifier</h3>
              {file.identifiers.map((i: any, idx: number) => (
                <p key={idx} className="text-xs py-1 border-t border-white/5 font-mono">
                  {i.id_type}: {i.id_value} <span className="text-gray-600">(zuletzt {new Date(i.last_seen).toLocaleDateString('de-DE')})</span>
                </p>
              ))}
            </div>
            <div className="panel">
              <h3 className="font-semibold text-white mb-2 text-sm">Fahrzeuge & Immobilien</h3>
              {file.vehicles.map((v: any, idx: number) => (
                <p key={idx} className="text-sm py-1 border-t border-white/5">{v.plate} · {v.label} · {Number(v.mileage_km).toFixed(0)} km</p>
              ))}
              {file.properties.map((p: any) => (
                <p key={p.id} className="text-sm py-1 border-t border-white/5">{p.label} ({p.prop_type})</p>
              ))}
            </div>
            <div className="panel">
              <h3 className="font-semibold text-white mb-2 text-sm">Sanktionen & Bußgelder</h3>
              {file.bans.map((b: any) => (
                <p key={b.id} className="text-sm py-1 border-t border-white/5 text-red-400">
                  Ban #{b.id}: {b.reason} {b.revoked_at ? '(aufgehoben)' : b.expires_at ? `bis ${new Date(b.expires_at).toLocaleDateString('de-DE')}` : '(permanent)'}
                </p>
              ))}
              {file.fines.map((f: any) => (
                <p key={f.id} className="text-xs py-1 border-t border-white/5">
                  Bußgeld #{f.id} · {f.law_code} · {formatMoney(f.amount)} · {f.status}
                </p>
              ))}
              {file.bans.length === 0 && file.fines.length === 0 && (
                <p className="text-sm text-gray-500">Keine Einträge.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
