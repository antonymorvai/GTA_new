'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface Question { id: string; question: string; options: string[] }
interface Application { id: number; status: string; test_score: number; test_total: number; review_note: string | null; created_at: string }

export default function WhitelistPage() {
  const [questions, setQuestions] = useState<Question[]>([]);
  const [apps, setApps] = useState<Application[]>([]);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [concept, setConcept] = useState('');
  const [age, setAge] = useState('');
  const [experience, setExperience] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api<Question[]>('/v1/ucp/whitelist/questions').then(setQuestions).catch((e) => setError(e.message));
    api<Application[]>('/v1/ucp/whitelist/status').then(setApps).catch(() => undefined);
  }, []);

  const hasOpen = apps.some((a) => a.status === 'pending' || a.status === 'approved');

  async function submit() {
    setError(null);
    setBusy(true);
    try {
      const res = await api<{ score: number; total: number }>('/v1/ucp/whitelist/apply', {
        method: 'POST',
        body: JSON.stringify({
          answers,
          characterConcept: concept,
          age: Number(age),
          rpExperience: experience,
        }),
      });
      setSuccess(`Bewerbung eingereicht — Regeltest: ${res.score}/${res.total}. Das Team prüft sie zeitnah.`);
      setApps(await api('/v1/ucp/whitelist/status'));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const STATUS: Record<string, string> = {
    pending: '⏳ In Prüfung', approved: '✅ Angenommen', rejected: '❌ Abgelehnt',
  };

  return (
    <div className="max-w-2xl space-y-6">
      {apps.length > 0 && (
        <div className="panel">
          <h2 className="font-semibold text-white mb-2">Deine Bewerbungen</h2>
          {apps.map((a) => (
            <p key={a.id} className="text-sm py-1 border-t border-white/5">
              {new Date(a.created_at).toLocaleDateString('de-DE')} · Test {a.test_score}/{a.test_total} ·{' '}
              {STATUS[a.status]}{a.review_note && <span className="text-gray-400"> — {a.review_note}</span>}
            </p>
          ))}
        </div>
      )}

      {success && <div className="panel text-green-400 text-sm">{success}</div>}

      {!hasOpen && !success && (
        <>
          <div className="panel space-y-3">
            <h1 className="font-semibold text-white">Bewerbung</h1>
            <label className="block text-sm text-gray-400">
              Dein Alter (OOC)
              <input className="input mt-1" type="number" value={age} onChange={(e) => setAge(e.target.value)} min={16} max={99} />
            </label>
            <label className="block text-sm text-gray-400">
              Deine RP-Erfahrung
              <textarea className="input mt-1" rows={3} value={experience}
                onChange={(e) => setExperience(e.target.value)}
                placeholder="Bisherige Server, Rollen, wie lange …" />
            </label>
            <label className="block text-sm text-gray-400">
              Charakterkonzept (min. 300 Zeichen) — {concept.length}/300
              <textarea className="input mt-1" rows={8} value={concept}
                onChange={(e) => setConcept(e.target.value)}
                placeholder="Wer ist dein Charakter? Herkunft, Motivation, Ziele, Schwächen …" />
            </label>
          </div>

          <div className="panel space-y-5">
            <h2 className="font-semibold text-white">Regeltest ({questions.length} Fragen, 8 richtige nötig)</h2>
            {questions.map((q, qi) => (
              <div key={q.id}>
                <p className="text-sm text-white mb-2">{qi + 1}. {q.question}</p>
                <div className="space-y-1">
                  {q.options.map((opt, oi) => (
                    <label key={oi} className="flex items-start gap-2 text-sm text-gray-300 cursor-pointer">
                      <input type="radio" name={q.id} checked={answers[q.id] === oi}
                        onChange={() => setAnswers({ ...answers, [q.id]: oi })} className="mt-1" />
                      {opt}
                    </label>
                  ))}
                </div>
              </div>
            ))}
          </div>

          {error && <p className="text-red-400 text-sm">{error}</p>}
          <button className="btn w-full" disabled={busy || Object.keys(answers).length < questions.length}
            onClick={submit}>
            Bewerbung einreichen
          </button>
        </>
      )}
    </div>
  );
}
