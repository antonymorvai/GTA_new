'use client';

import { useMemo, useState } from 'react';
import { api } from '@/lib/api';
import GameMap, { toSvg } from '@/components/GameMap';

interface Sample { time: string; x: number; y: number; z: number; heading: number; speed: number }

export default function ReplayPage() {
  const [charId, setCharId] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [samples, setSamples] = useState<Sample[]>([]);
  const [cursor, setCursor] = useState(0);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      const data = await api<Sample[]>(
        `/v1/acp/replay/${charId.trim()}?from=${encodeURIComponent(new Date(from).toISOString())}&to=${encodeURIComponent(new Date(to).toISOString())}`);
      setSamples(data);
      setCursor(data.length - 1);
      if (data.length === 0) setError('Keine Bewegungsdaten im Zeitfenster.');
    } catch (e) { setError((e as Error).message); }
  }

  const path = useMemo(() =>
    samples.slice(0, cursor + 1).map((s) => {
      const p = toSvg(s.x, s.y);
      return `${p.x},${p.y}`;
    }).join(' '), [samples, cursor]);

  const current = samples[cursor];
  const currentPos = current ? toSvg(current.x, current.y) : null;

  function play() {
    setCursor(0);
    let i = 0;
    const timer = setInterval(() => {
      i += Math.max(1, Math.floor(samples.length / 300));
      if (i >= samples.length) { i = samples.length - 1; clearInterval(timer); }
      setCursor(i);
    }, 50);
  }

  return (
    <div className="space-y-4">
      <div className="panel">
        <h1 className="font-semibold text-white mb-3">Session-Replay — Bewegungsdaten auf der Karte abspielen</h1>
        <div className="grid grid-cols-4 gap-2">
          <input className="input" placeholder="Charakter-ID" value={charId} onChange={(e) => setCharId(e.target.value)} />
          <input className="input" type="datetime-local" value={from} onChange={(e) => setFrom(e.target.value)} />
          <input className="input" type="datetime-local" value={to} onChange={(e) => setTo(e.target.value)} />
          <button className="btn" onClick={load}>Laden</button>
        </div>
        {error && <p className="text-red-400 text-sm mt-2">{error}</p>}
      </div>

      {samples.length > 0 && (
        <div className="panel space-y-3">
          <div className="flex items-center gap-3">
            <button className="btn text-xs" onClick={play}>▶ Abspielen</button>
            <input type="range" min={0} max={samples.length - 1} value={cursor}
              onChange={(e) => setCursor(Number(e.target.value))} className="flex-1" />
            <span className="text-xs text-gray-400 whitespace-nowrap">
              {current && new Date(current.time).toLocaleTimeString('de-DE')} ·
              {' '}{current && (current.speed * 3.6).toFixed(0)} km/h ·
              {' '}{cursor + 1}/{samples.length}
            </span>
          </div>
          <GameMap>
            <polyline points={path} fill="none" stroke="#4f8cff" strokeWidth="1.5" opacity="0.8" />
            {currentPos && (
              <circle cx={currentPos.x} cy={currentPos.y} r="5" fill="#4f8cff" stroke="white" strokeWidth="1.5" />
            )}
          </GameMap>
        </div>
      )}
    </div>
  );
}
