'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Application {
  id: number; account_id: number; username: string;
  answers: { characterConcept: string; age: number; rpExperience: string } | string;
  test_score: number; test_total: number; status: string; created_at: string;
}

export default function ApplicationsPage() {
  const [rows, setRows] = useState<Application[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try { setRows(await api('/v1/acp/applications?status=pending')); }
    catch (e) { setError((e as Error).message); }
  }
  useEffect(() => { void load(); }, []);

  async function decide(id: number, approve: boolean) {
    const note = approve
      ? (prompt('Optionale Notiz:') ?? '')
      : prompt('Ablehnungs-Begründung (Pflicht):');
    if (!approve && !note) return;
    try {
      await api(`/v1/acp/applications/${id}/decide`, {
        method: 'POST', body: JSON.stringify({ approve, note }),
      });
      await load();
    } catch (e) { setError((e as Error).message); }
  }

  function answersOf(a: Application) {
    return typeof a.answers === 'string' ? JSON.parse(a.answers) : a.answers;
  }

  return (
    <div className="space-y-4">
      <div className="panel"><h1 className="font-semibold text-white">Offene Whitelist-Bewerbungen ({rows.length})</h1></div>
      {error && <p className="text-red-400 text-sm">{error}</p>}
      {rows.map((a) => {
        const ans = answersOf(a);
        return (
          <div key={a.id} className="panel space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="font-semibold text-white">
                {a.username} <span className="text-gray-500 text-sm">(Account {a.account_id})</span>
              </h2>
              <span className="text-sm text-gray-400">
                Regeltest {a.test_score}/{a.test_total} · {new Date(a.created_at).toLocaleString('de-DE')}
              </span>
            </div>
            <p className="text-xs text-gray-500">Alter: {ans.age} · Erfahrung: {ans.rpExperience}</p>
            <p className="text-sm text-gray-300 whitespace-pre-wrap border-l-2 border-white/10 pl-3">
              {ans.characterConcept}
            </p>
            <div className="flex gap-2">
              <button className="btn text-xs" onClick={() => decide(a.id, true)}>Annehmen</button>
              <button className="btn-ghost text-xs" onClick={() => decide(a.id, false)}>Ablehnen</button>
            </div>
          </div>
        );
      })}
      {rows.length === 0 && <p className="text-gray-500 text-sm">Keine offenen Bewerbungen. 🎉</p>}
    </div>
  );
}
