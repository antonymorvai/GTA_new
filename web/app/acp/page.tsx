'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

export default function AcpHome() {
  const [me, setMe] = useState<{ username: string; permissions: string[] } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<{ username: string; permissions: string[] }>('/v1/auth/me')
      .then(setMe)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="text-red-400">{error} — bitte anmelden.</p>;
  if (!me) return <p className="text-gray-400">Lade …</p>;

  return (
    <div className="space-y-4">
      <div className="panel">
        <h1 className="text-xl font-semibold text-white">Admin Control Panel</h1>
        <p className="text-sm text-gray-400 mt-1">Angemeldet als {me.username}</p>
      </div>
      <div className="panel">
        <h2 className="font-semibold text-white mb-2">Deine Berechtigungen</h2>
        <div className="flex flex-wrap gap-2">
          {me.permissions.length === 0 && <p className="text-sm text-gray-500">Keine ACP-Berechtigungen.</p>}
          {me.permissions.map((p) => (
            <span key={p} className="text-xs bg-white/10 rounded px-2 py-1">{p}</span>
          ))}
        </div>
      </div>
      <div className="panel text-sm text-gray-400">
        <h2 className="font-semibold text-white mb-2">Hinweis</h2>
        <p>Alle Ansichten arbeiten direkt auf dem append-only Log-Store.
        Jede Abfrage — auch reines Anschauen — erzeugt ein admin.access-Event,
        das für Admins unterhalb der Projektleitung weder löschbar noch filterbar ist.</p>
      </div>
    </div>
  );
}
