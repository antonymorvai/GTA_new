'use client';

import { useState } from 'react';
import { api } from '@/lib/api';

export default function SanctionsPage() {
  const [form, setForm] = useState({ accountId: '', kind: 'warn', reason: '', evidence: '', hours: '0' });
  const [history, setHistory] = useState<any[] | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setError(null);
    setMessage(null);
    try {
      const res = await api<{ ok: true; banId?: number }>('/v1/acp/sanctions', {
        method: 'POST',
        body: JSON.stringify({
          accountId: Number(form.accountId), kind: form.kind,
          reason: form.reason, evidence: form.evidence,
          hours: Number(form.hours),
        }),
      });
      setMessage(form.kind === 'ban'
        ? `Ban #${res.banId} ausgesprochen (greift beim nächsten Connect-Versuch).`
        : 'Verwarnung dokumentiert.');
      await loadHistory();
    } catch (e) { setError((e as Error).message); }
  }

  async function loadHistory() {
    if (!form.accountId) return;
    try { setHistory(await api(`/v1/acp/sanctions/${form.accountId}`)); }
    catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="max-w-2xl space-y-4">
      <div className="panel space-y-3">
        <h1 className="font-semibold text-white">Sanktion aussprechen</h1>
        <p className="text-xs text-gray-500">
          Begründung UND Beweis-Verweis (Log-Permalink, Ticket-Nr., Clip) sind Pflicht.
          Jede Sanktion landet unlöschbar in der Historie + im Log-Store.
        </p>
        <div className="grid grid-cols-3 gap-2">
          <input className="input" placeholder="Account-ID" value={form.accountId}
            onChange={(e) => setForm({ ...form, accountId: e.target.value })}
            onBlur={loadHistory} />
          <select className="input" value={form.kind}
            onChange={(e) => setForm({ ...form, kind: e.target.value })}>
            <option value="warn">Verwarnung</option>
            <option value="ban">Ban</option>
          </select>
          {form.kind === 'ban' && (
            <input className="input" placeholder="Stunden (0 = permanent)" value={form.hours}
              onChange={(e) => setForm({ ...form, hours: e.target.value })} />
          )}
        </div>
        <textarea className="input" rows={3} placeholder="Begründung (min. 10 Zeichen)"
          value={form.reason} onChange={(e) => setForm({ ...form, reason: e.target.value })} />
        <input className="input" placeholder="Beweis: Log-Permalink / Ticket-Nr. / Clip-URL (Pflicht)"
          value={form.evidence} onChange={(e) => setForm({ ...form, evidence: e.target.value })} />
        {error && <p className="text-red-400 text-sm">{error}</p>}
        {message && <p className="text-green-400 text-sm">{message}</p>}
        <button className="btn" onClick={submit}>
          {form.kind === 'ban' ? 'Ban aussprechen' : 'Verwarnung dokumentieren'}
        </button>
      </div>

      {history && (
        <div className="panel">
          <h2 className="font-semibold text-white mb-2 text-sm">Sanktionshistorie Account {form.accountId}</h2>
          {history.map((s, i) => (
            <p key={i} className="text-sm py-1 border-t border-white/5">
              <span className={s.kind === 'ban' ? 'text-red-400' : 'text-yellow-400'}>{s.kind}</span>
              {' · '}{s.reason}
              <span className="block text-xs text-gray-500">
                {new Date(s.created_at).toLocaleString('de-DE')} · von {s.issued_by_name} · Beweis: {s.evidence}
              </span>
            </p>
          ))}
          {history.length === 0 && <p className="text-sm text-gray-500">Keine Einträge — weiße Weste.</p>}
        </div>
      )}
    </div>
  );
}
