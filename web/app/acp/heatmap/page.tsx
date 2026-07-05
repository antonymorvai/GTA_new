'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import GameMap, { toSvg } from '@/components/GameMap';

interface Cell { gx: number; gy: number; n: number }

export default function HeatmapPage() {
  const [cells, setCells] = useState<Cell[]>([]);
  const [hours, setHours] = useState(24);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Cell[]>(`/v1/acp/heatmap?hours=${hours}`).then(setCells).catch((e) => setError(e.message));
  }, [hours]);

  const max = Math.max(1, ...cells.map((c) => Number(c.n)));

  return (
    <div className="space-y-4">
      <div className="panel flex items-center gap-3">
        <h1 className="font-semibold text-white flex-1">Aktivitäts-Heatmap (Bewegungsdaten)</h1>
        {[6, 24, 72, 168].map((h) => (
          <button key={h} onClick={() => setHours(h)}
            className={`text-xs px-3 py-1.5 rounded ${hours === h ? 'bg-accent text-white' : 'text-gray-400'}`}>
            {h} h
          </button>
        ))}
      </div>
      {error && <p className="text-red-400 text-sm">{error}</p>}
      <div className="panel">
        <GameMap>
          {cells.map((c, i) => {
            const p = toSvg(Number(c.gx), Number(c.gy));
            const intensity = Number(c.n) / max;
            return (
              <circle key={i} cx={p.x} cy={p.y} r={2 + intensity * 8}
                fill={intensity > 0.6 ? '#ef4444' : intensity > 0.25 ? '#f59e0b' : '#4f8cff'}
                opacity={0.25 + intensity * 0.6} />
            );
          })}
        </GameMap>
        <p className="text-xs text-gray-500 mt-2">
          {cells.length} aktive Zellen (100-m-Raster) · Rot = Hotspot. Grundlage für
          Streifen-Planung und Deal-Spot-Verlagerung.
        </p>
      </div>
    </div>
  );
}
