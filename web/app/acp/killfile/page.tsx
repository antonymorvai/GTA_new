'use client';

import { useState } from 'react';
import { api } from '@/lib/api';
import GameMap, { toSvg } from '@/components/GameMap';

interface KillFile {
  down: { time: string; payload: Record<string, any> };
  killerCharacterId: number | null;
  damage: Array<{ time: string; actor_character: number; payload: Record<string, any> }>;
  movement: Array<{ character_id: number; time: string; x: number; y: number; speed: number }>;
}

export default function KillFilePage() {
  const [charId, setCharId] = useState('');
  const [at, setAt] = useState('');
  const [file, setFile] = useState<KillFile | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      setFile(await api(`/v1/acp/killfile/${charId.trim()}?at=${encodeURIComponent(new Date(at).toISOString())}`));
    } catch (e) { setError((e as Error).message); }
  }

  const victimPath = file?.movement
    .filter((m) => Number(m.character_id) === Number(charId))
    .map((m) => { const p = toSvg(m.x, m.y); return `${p.x},${p.y}`; }).join(' ');
  const killerPath = file?.killerCharacterId ? file.movement
    .filter((m) => Number(m.character_id) === Number(file.killerCharacterId))
    .map((m) => { const p = toSvg(m.x, m.y); return `${p.x},${p.y}`; }).join(' ') : '';

  const downPos = file?.down.payload && file.movement.length > 0
    ? toSvg(
        file.movement.filter((m) => Number(m.character_id) === Number(charId)).at(-1)?.x ?? 0,
        file.movement.filter((m) => Number(m.character_id) === Number(charId)).at(-1)?.y ?? 0)
    : null;

  return (
    <div className="space-y-4">
      <div className="panel">
        <h1 className="font-semibold text-white mb-1">Kill-Akte</h1>
        <p className="text-xs text-gray-500 mb-3">
          Charakter des Opfers + ungefährer Zeitpunkt des Downs (±5 min) →
          vollständiger Kampf-Kontext: Verursacher, jeder Schaden, letzte 60 s Bewegung.
        </p>
        <div className="grid grid-cols-3 gap-2">
          <input className="input" placeholder="Opfer Charakter-ID" value={charId} onChange={(e) => setCharId(e.target.value)} />
          <input className="input" type="datetime-local" value={at} onChange={(e) => setAt(e.target.value)} />
          <button className="btn" onClick={load}>Akte öffnen</button>
        </div>
        {error && <p className="text-red-400 text-sm mt-2">{error}</p>}
      </div>

      {file && (
        <div className="grid lg:grid-cols-2 gap-4">
          <div className="space-y-4">
            <div className="panel">
              <h2 className="font-semibold text-white text-sm mb-2">Down-Ereignis</h2>
              <p className="text-sm">
                {new Date(file.down.time).toLocaleString('de-DE')} ·
                Ursache: {file.down.payload.cause} ·
                Verursacher: {file.killerCharacterId ? `Charakter ${file.killerCharacterId}` : 'unbekannt/Umgebung'}
              </p>
            </div>
            <div className="panel overflow-y-auto max-h-96">
              <h2 className="font-semibold text-white text-sm mb-2">Schadensereignisse (±60 s): {file.damage.length}</h2>
              {file.damage.map((d, i) => (
                <p key={i} className="text-xs py-1 border-t border-white/5">
                  {new Date(d.time).toLocaleTimeString('de-DE')} ·
                  Char {d.actor_character} → {d.payload.targetCharacterId ?? '?'} ·
                  {' '}{d.payload.zone} · {d.payload.damage} dmg · {Number(d.payload.distance).toFixed(0)} m
                </p>
              ))}
            </div>
          </div>
          <div className="panel">
            <h2 className="font-semibold text-white text-sm mb-2">
              Bewegung: <span className="text-accent">Opfer</span>
              {file.killerCharacterId && <> · <span className="text-red-400">Verursacher</span></>}
            </h2>
            <GameMap>
              {victimPath && <polyline points={victimPath} fill="none" stroke="#4f8cff" strokeWidth="1.5" />}
              {killerPath && <polyline points={killerPath} fill="none" stroke="#f87171" strokeWidth="1.5" />}
              {downPos && <circle cx={downPos.x} cy={downPos.y} r="6" fill="none" stroke="#f87171" strokeWidth="2" />}
            </GameMap>
          </div>
        </div>
      )}
    </div>
  );
}
