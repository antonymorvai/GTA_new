'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Ticket {
  id: number; category: string; subject: string; reported_ref: string | null;
  status: string; created_at: string; username: string; account_id: number;
}
interface Message { body: string; evidence: string | null; is_staff: number; created_at: string; username: string }

export default function AcpTicketsPage() {
  const [status, setStatus] = useState('open');
  const [rows, setRows] = useState<Ticket[]>([]);
  const [detail, setDetail] = useState<{ ticket: Ticket; messages: Message[] } | null>(null);
  const [reply, setReply] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function load(s = status) {
    try { setRows(await api(`/v1/acp/tickets?status=${s}`)); }
    catch (e) { setError((e as Error).message); }
  }
  useEffect(() => { void load(); }, [status]);

  async function open(id: number) {
    try { setDetail(await api(`/v1/acp/tickets/${id}`)); }
    catch (e) { setError((e as Error).message); }
  }

  async function send(close: boolean) {
    if (!detail) return;
    try {
      await api(`/v1/acp/tickets/${detail.ticket.id}/reply`, {
        method: 'POST', body: JSON.stringify({ body: reply, close }),
      });
      setReply('');
      setDetail(null);
      await load();
    } catch (e) { setError((e as Error).message); }
  }

  if (detail) {
    return (
      <div className="space-y-4 max-w-2xl">
        <button className="btn-ghost text-xs" onClick={() => setDetail(null)}>← Zurück</button>
        <div className="panel">
          <h1 className="font-semibold text-white">#{detail.ticket.id} · {detail.ticket.subject}</h1>
          <p className="text-xs text-gray-500">
            von {detail.ticket.username} (Account {detail.ticket.account_id}) · {detail.ticket.category}
            {detail.ticket.reported_ref && <span className="text-red-400"> · gemeldet: {detail.ticket.reported_ref}</span>}
          </p>
        </div>
        {detail.messages.map((m, i) => (
          <div key={i} className={`panel ${m.is_staff ? 'border-accent/40' : ''}`}>
            <p className="text-xs text-gray-500 mb-1">{m.is_staff ? '🛡 ' : ''}{m.username} · {new Date(m.created_at).toLocaleString('de-DE')}</p>
            <p className="text-sm whitespace-pre-wrap">{m.body}</p>
            {m.evidence && <p className="text-xs text-accent mt-2">Beweis: {m.evidence}</p>}
          </div>
        ))}
        <div className="panel space-y-2">
          <textarea className="input" rows={4} value={reply} onChange={(e) => setReply(e.target.value)}
            placeholder="Team-Antwort …" />
          <div className="flex gap-2">
            <button className="btn" onClick={() => send(false)} disabled={reply.trim().length < 2}>Antworten</button>
            <button className="btn-ghost" onClick={() => send(true)} disabled={reply.trim().length < 2}>Antworten & Schließen</button>
          </div>
        </div>
        {error && <p className="text-red-400 text-sm">{error}</p>}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="panel flex items-center gap-3">
        <h1 className="font-semibold text-white flex-1">Ticket-Queue</h1>
        {['open', 'answered', 'closed'].map((s) => (
          <button key={s} onClick={() => setStatus(s)}
            className={`text-xs px-3 py-1.5 rounded ${status === s ? 'bg-accent text-white' : 'text-gray-400'}`}>
            {s}
          </button>
        ))}
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}
      <div className="panel">
        {rows.map((t) => (
          <button key={t.id} onClick={() => open(t.id)}
            className="block w-full text-left px-3 py-2 hover:bg-white/5 rounded text-sm border-t border-white/5 first:border-0">
            <span className={t.category === 'report' ? 'text-red-400' : 'text-white'}>
              #{t.id} [{t.category}] {t.subject}
            </span>
            <span className="text-gray-500"> · {t.username} · {new Date(t.created_at).toLocaleString('de-DE')}</span>
          </button>
        ))}
        {rows.length === 0 && <p className="text-sm text-gray-500 p-3">Queue ist leer.</p>}
      </div>
    </div>
  );
}
