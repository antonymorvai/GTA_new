'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import GameMap, { toSvg } from '@/components/GameMap';

interface LivePlayer { character_id: number; name: string; x: number; y: number; speed: number; time: string }

export default function LiveMapPage() {
  const [players, setPlayers] = useState<LivePlayer[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    async function tick() {
      try {
        const data = await api<LivePlayer[]>('/v1/acp/livemap');
        if (active) setPlayers(data);
      } catch (e) { if (active) setError((e as Error).message); }
    }
    void tick();
    const timer = setInterval(tick, 5000);
    return () => { active = false; clearInterval(timer); };
  }, []);

  return (
    <div className="space-y-4">
      <div className="panel flex items-center justify-between">
        <h1 className="font-semibold text-white">Live-Karte</h1>
        <span className="text-sm text-gray-400">{players.length} Spieler · aktualisiert alle 5 s</span>
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}
      <div className="panel">
        <GameMap>
          {players.map((p) => {
            const pos = toSvg(p.x, p.y);
            return (
              <g key={p.character_id}>
                <circle cx={pos.x} cy={pos.y} r="4" fill="#22c55e" stroke="white" strokeWidth="1" />
                <text x={pos.x + 6} y={pos.y + 3} fill="#9ca3af" fontSize="9">{p.name}</text>
              </g>
            );
          })}
        </GameMap>
      </div>
    </div>
  );
}
