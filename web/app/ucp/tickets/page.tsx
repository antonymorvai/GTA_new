'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Ticket { id: number; category: string; subject: string; status: string; created_at: string }
interface Message { body: string; evidence: string | null; is_staff: number; created_at: string; username: string }

const CATEGORIES = [
  ['support', 'Allgemeiner Support'], ['bug', 'Bug-Meldung'], ['report', 'Spielerreport'],
  ['complaint', 'Beschwerde'], ['refund', 'Rückerstattung'], ['other', 'Sonstiges'],
] as const;

export default function TicketsPage() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [detail, setDetail] = useState<{ ticket: Ticket & { reported_ref: string | null }; messages: Message[] } | null>(null);
  const [showNew, setShowNew] = useState(false);
  const [form, setForm] = useState({ category: 'support', subject: '', body: '', reportedRef: '', evidence: '' });
  const [reply, setReply] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try { setTickets(await api('/v1/ucp/tickets')); }
    catch (e) { setError((e as Error).message); }
  }
  useEffect(() => { void load(); }, []);

  async function create() {
    setError(null);
    try {
      const res = await api<{ id: number }>('/v1/ucp/tickets', {
        method: 'POST',
        body: JSON.stringify({
          category: form.category, subject: form.subject, body: form.body,
          reportedRef: form.reportedRef || undefined, evidence: form.evidence || undefined,
        }),
      });
      setShowNew(false);
      setForm({ category: 'support', subject: '', body: '', reportedRef: '', evidence: '' });
      await load();
      await open(res.id);
    } catch (e) { setError((e as Error).message); }
  }

  async function open(id: number) {
    try { setDetail(await api(`/v1/ucp/tickets/${id}`)); }
    catch (e) { setError((e as Error).message); }
  }

  async function sendReply() {
    if (!detail) return;
    try {
      await api(`/v1/ucp/tickets/${detail.ticket.id}/messages`, {
        method: 'POST', body: JSON.stringify({ body: reply }),
      });
      setReply('');
      await open(detail.ticket.id);
    } catch (e) { setError((e as Error).message); }
  }

  if (detail) {
    return (
      <div className="max-w-2xl space-y-4">
        <button className="btn-ghost text-xs" onClick={() => setDetail(null)}>← Zurück</button>
        <div className="panel">
          <h1 className="font-semibold text-white">#{detail.ticket.id} · {detail.ticket.subject}</h1>
          <p className="text-xs text-gray-500">{detail.ticket.category}{detail.ticket.reported_ref && ` · gemeldet: ${detail.ticket.reported_ref}`} · {detail.ticket.status}</p>
        </div>
        {detail.messages.map((m, i) => (
          <div key={i} className={`panel ${m.is_staff ? 'border-accent/40' : ''}`}>
            <p className="text-xs text-gray-500 mb-1">
              {m.is_staff ? '🛡 Team · ' : ''}{m.username} · {new Date(m.created_at).toLocaleString('de-DE')}
            </p>
            <p className="text-sm whitespace-pre-wrap">{m.body}</p>
            {m.evidence && <p className="text-xs text-gray-500 mt-2">Beweis: {m.evidence}</p>}
          </div>
        ))}
        {detail.ticket.status !== 'closed' && (
          <div className="panel space-y-2">
            <textarea className="input" rows={3} value={reply} onChange={(e) => setReply(e.target.value)}
              placeholder="Antwort schreiben …" />
            <button className="btn" onClick={sendReply} disabled={reply.trim().length < 2}>Senden</button>
          </div>
        )}
        {error && <p className="text-red-400 text-sm">{error}</p>}
      </div>
    );
  }

  return (
    <div className="max-w-2xl space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="font-semibold text-white">Meine Tickets</h1>
        <button className="btn" onClick={() => setShowNew(!showNew)}>Neues Ticket</button>
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}

      {showNew && (
        <div className="panel space-y-3">
          <select className="input" value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}>
            {CATEGORIES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
          {form.category === 'report' && (
            <input className="input" placeholder="Gemeldeter Spieler (Name / Charakter / ID) — Pflicht"
              value={form.reportedRef} onChange={(e) => setForm({ ...form, reportedRef: e.target.value })} />
          )}
          <input className="input" placeholder="Betreff" value={form.subject}
            onChange={(e) => setForm({ ...form, subject: e.target.value })} />
          <textarea className="input" rows={5} placeholder="Beschreibung (min. 20 Zeichen)"
            value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
          <input className="input" placeholder="Beweise (Links zu Clips/Screenshots, optional)"
            value={form.evidence} onChange={(e) => setForm({ ...form, evidence: e.target.value })} />
          <button className="btn" onClick={create}>Einreichen</button>
        </div>
      )}

      <div className="panel">
        {tickets.map((t) => (
          <button key={t.id} onClick={() => open(t.id)}
            className="block w-full text-left px-3 py-2 hover:bg-white/5 rounded text-sm border-t border-white/5 first:border-0">
            <span className="text-white">#{t.id} {t.subject}</span>
            <span className="text-gray-500"> · {t.category} · {t.status} · {new Date(t.created_at).toLocaleDateString('de-DE')}</span>
          </button>
        ))}
        {tickets.length === 0 && <p className="text-sm text-gray-500 p-3">Keine Tickets.</p>}
      </div>
    </div>
  );
}
