'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, setToken } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [totp, setTotp] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await api<{ token: string }>('/v1/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username, password, totp: totp || undefined }),
      });
      setToken(res.token);
      router.push('/ucp');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-sm mx-auto panel">
      <h1 className="text-xl font-semibold text-white mb-4">Anmelden</h1>
      <form onSubmit={submit} className="space-y-3">
        <input className="input" placeholder="Benutzername" value={username}
          onChange={(e) => setUsername(e.target.value)} required />
        <input className="input" type="password" placeholder="Passwort" value={password}
          onChange={(e) => setPassword(e.target.value)} required />
        <input className="input" placeholder="2FA-Code (falls aktiviert)" value={totp}
          onChange={(e) => setTotp(e.target.value)} maxLength={8} />
        {error && <p className="text-sm text-red-400">{error}</p>}
        <button className="btn w-full" disabled={busy}>Anmelden</button>
      </form>
    </div>
  );
}
