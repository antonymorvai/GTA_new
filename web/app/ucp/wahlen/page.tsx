'use client';

import { useEffect, useState } from 'react';
import { api, formatMoney } from '@/lib/api';

interface Candidate { id: number; first_name: string; last_name: string; statement: string; votes: number | null }
interface Election {
  id: number; office: string; title: string; phase: string;
  registration_ends_at: string; voting_ends_at: string;
  winner_character_id: number | null; candidates: Candidate[];
}
interface Proposal {
  id: number; law_code: string; law_title: string; rationale: string;
  current_fine: number; new_fine: number; current_jail: number; new_jail_minutes: number;
  status: string; votes_yes: number; votes_no: number; voting_ends_at: string;
  first_name: string; last_name: string;
}

const PHASE: Record<string, string> = {
  registration: '📝 Kandidaten-Registrierung', voting: '🗳 Abstimmung läuft', closed: '✅ Abgeschlossen',
};

export default function ElectionsPage() {
  const [elections, setElections] = useState<Election[]>([]);
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [isGovMember, setIsGovMember] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [proposalForm, setProposalForm] = useState({ lawCode: '', fine: '', jail: '', rationale: '' });

  async function load() {
    try {
      setElections(await api('/v1/ucp/government/elections'));
      setProposals(await api('/v1/ucp/government/proposals'));
      const status = await api<{ isMember: boolean }>('/v1/ucp/government/status');
      setIsGovMember(status.isMember);
    } catch (e) { setError((e as Error).message); }
  }
  useEffect(() => { void load(); }, []);

  async function act(fn: () => Promise<unknown>, successMsg: string) {
    setError(null); setMessage(null);
    try { await fn(); setMessage(successMsg); await load(); }
    catch (e) { setError((e as Error).message); }
  }

  return (
    <div className="max-w-3xl space-y-6">
      {error && <p className="text-red-400 text-sm">{error}</p>}
      {message && <p className="text-green-400 text-sm">{message}</p>}

      <section className="space-y-4">
        <h1 className="font-semibold text-white text-lg">Wahlen</h1>
        {elections.map((e) => (
          <div key={e.id} className="panel space-y-3">
            <div className="flex justify-between items-center">
              <h2 className="font-semibold text-white">{e.title}</h2>
              <span className="text-xs text-gray-400">{PHASE[e.phase]}</span>
            </div>
            {e.candidates.map((c) => (
              <div key={c.id} className="border-t border-white/5 pt-2">
                <p className="text-sm text-white">
                  {c.first_name} {c.last_name}
                  {e.phase === 'closed' && c.votes != null && (
                    <span className="text-accent ml-2">{c.votes} Stimmen</span>
                  )}
                </p>
                <p className="text-xs text-gray-400">{c.statement}</p>
                {e.phase === 'voting' && (
                  <button className="btn text-xs mt-2"
                    onClick={() => act(
                      () => api(`/v1/ucp/government/elections/${e.id}/vote`, {
                        method: 'POST', body: JSON.stringify({ candidateId: c.id }),
                      }), 'Stimme abgegeben — deine Wahl bleibt geheim.')}>
                    Wählen
                  </button>
                )}
              </div>
            ))}
            {e.candidates.length === 0 && <p className="text-sm text-gray-500">Noch keine Kandidaten.</p>}
            {e.phase === 'registration' && (
              <button className="btn-ghost text-xs"
                onClick={() => {
                  const characterId = prompt('Mit welchem Charakter (Charakter-ID) kandidierst du?');
                  const statement = characterId && prompt('Dein Wahlprogramm (min. 30 Zeichen):');
                  if (characterId && statement) {
                    void act(() => api(`/v1/ucp/government/elections/${e.id}/candidacy`, {
                      method: 'POST',
                      body: JSON.stringify({ characterId: Number(characterId), statement }),
                    }), 'Kandidatur eingereicht.');
                  }
                }}>
                Kandidieren
              </button>
            )}
          </div>
        ))}
        {elections.length === 0 && <p className="text-gray-500 text-sm">Aktuell keine Wahlen angesetzt.</p>}
      </section>

      <section className="space-y-4">
        <h1 className="font-semibold text-white text-lg">Gesetzgebung</h1>
        {isGovMember && (
          <div className="panel space-y-2">
            <h2 className="text-sm font-semibold text-white">Gesetzentwurf einbringen</h2>
            <div className="grid grid-cols-3 gap-2">
              <input className="input" placeholder="Gesetz (z. B. StVO-1)" value={proposalForm.lawCode}
                onChange={(ev) => setProposalForm({ ...proposalForm, lawCode: ev.target.value })} />
              <input className="input" placeholder="Bußgeld €" value={proposalForm.fine}
                onChange={(ev) => setProposalForm({ ...proposalForm, fine: ev.target.value })} />
              <input className="input" placeholder="Haft (min)" value={proposalForm.jail}
                onChange={(ev) => setProposalForm({ ...proposalForm, jail: ev.target.value })} />
            </div>
            <textarea className="input" rows={2} placeholder="Begründung (min. 30 Zeichen)"
              value={proposalForm.rationale}
              onChange={(ev) => setProposalForm({ ...proposalForm, rationale: ev.target.value })} />
            <button className="btn text-xs" onClick={() => act(
              () => api('/v1/ucp/government/proposals', {
                method: 'POST',
                body: JSON.stringify({
                  lawCode: proposalForm.lawCode.trim(), fine: Number(proposalForm.fine) * 100,
                  jailMinutes: Number(proposalForm.jail), rationale: proposalForm.rationale,
                }),
              }), 'Entwurf eingebracht — Abstimmung läuft 24 h.')}>
              Einbringen
            </button>
          </div>
        )}
        {proposals.map((p) => (
          <div key={p.id} className="panel">
            <p className="text-sm text-white">
              #{p.id} {p.law_code} — {p.law_title}
              <span className="text-xs text-gray-400 ml-2">von {p.first_name} {p.last_name} · {p.status}</span>
            </p>
            <p className="text-xs text-gray-400 mt-1">
              {formatMoney(p.current_fine)} / {p.current_jail} min → <span className="text-accent">
              {formatMoney(p.new_fine)} / {p.new_jail_minutes} min</span>
              {' · '}Ja {p.votes_yes} : Nein {p.votes_no}
            </p>
            <p className="text-xs text-gray-500 mt-1">{p.rationale}</p>
            {p.status === 'voting' && isGovMember && (
              <div className="flex gap-2 mt-2">
                <button className="btn text-xs" onClick={() => act(
                  () => api(`/v1/ucp/government/proposals/${p.id}/vote`, {
                    method: 'POST', body: JSON.stringify({ yes: true }),
                  }), 'Ja-Stimme registriert (namentlich).')}>Dafür</button>
                <button className="btn-ghost text-xs" onClick={() => act(
                  () => api(`/v1/ucp/government/proposals/${p.id}/vote`, {
                    method: 'POST', body: JSON.stringify({ yes: false }),
                  }), 'Nein-Stimme registriert (namentlich).')}>Dagegen</button>
              </div>
            )}
          </div>
        ))}
        {proposals.length === 0 && <p className="text-gray-500 text-sm">Keine Gesetzentwürfe.</p>}
      </section>
    </div>
  );
}
