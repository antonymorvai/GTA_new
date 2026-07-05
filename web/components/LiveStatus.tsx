'use client';

import { useEffect, useState } from 'react';

interface Status { online: number; maxSlots: number; charactersTotal: number }

export default function LiveStatus() {
  const [status, setStatus] = useState<Status | null>(null);

  useEffect(() => {
    let active = true;
    async function tick() {
      try {
        const res = await fetch('/api/v1/public/status');
        if (res.ok && active) setStatus(await res.json());
      } catch { /* Widget ist optional */ }
    }
    void tick();
    const timer = setInterval(tick, 30000);
    return () => { active = false; clearInterval(timer); };
  }, []);

  if (!status) return null;

  return (
    <div className="inline-flex items-center gap-2 mt-6 px-4 py-2 rounded-full border border-white/15 text-sm">
      <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
      <span className="text-white font-medium">{status.online}/{status.maxSlots}</span>
      <span className="text-gray-400">Spieler online · {status.charactersTotal} Charaktere leben in Los Santos</span>
    </div>
  );
}
