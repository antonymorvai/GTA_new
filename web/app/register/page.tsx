'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';

export default function RegisterPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api('/v1/auth/register', {
        method: 'POST',
        body: JSON.stringify({ username, email, password }),
      });
      router.push('/login');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-sm mx-auto panel">
      <h1 className="text-xl font-semibold text-white mb-1">Registrieren</h1>
      <p className="text-xs text-gray-400 mb-4">
        Nach der Registrierung folgt die Whitelist-Bewerbung — erst nach
        Freischaltung kannst du den Server betreten.
      </p>
      <form onSubmit={submit} className="space-y-3">
        <input className="input" placeholder="Benutzername (3–32 Zeichen)" value={username}
          onChange={(e) => setUsername(e.target.value)} required />
        <input className="input" type="email" placeholder="E-Mail" value={email}
          onChange={(e) => setEmail(e.target.value)} required />
        <input className="input" type="password" placeholder="Passwort (min. 10 Zeichen)" value={password}
          onChange={(e) => setPassword(e.target.value)} required minLength={10} />
        {error && <p className="text-sm text-red-400">{error}</p>}
        <button className="btn w-full" disabled={busy}>Account erstellen</button>
      </form>
    </div>
  );
}
