'use client';

import { useEffect, useState } from 'react';
import { api, formatMoney } from '@/lib/api';

interface Dashboard {
  treasury: { balance: number; updated_at: string } | null;
  moneySupply: { playerCash: number; playerBank: number; companyFunds: number };
  flowDaily: Array<{ day: string; type: string; reason: string; total_amount: number; events: number }>;
  treasuryEvents: Array<{ time: string; payload: Record<string, any> }>;
}

export default function EconomyPage() {
  const [data, setData] = useState<Dashboard | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Dashboard>('/v1/acp/economy').then(setData).catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="text-red-400">{error}</p>;
  if (!data) return <p className="text-gray-400">Lade …</p>;

  const supply = data.moneySupply;
  const m1 = supply.playerCash + supply.playerBank + supply.companyFunds;

  // Tages-Bilanz: erschaffen vs. vernichtet
  const daily = new Map<string, { created: number; destroyed: number }>();
  for (const row of data.flowDaily) {
    const key = String(row.day).slice(0, 10);
    const entry = daily.get(key) ?? { created: 0, destroyed: 0 };
    if (row.type === 'money.create') entry.created += Number(row.total_amount);
    if (row.type === 'money.destroy') entry.destroyed += Number(row.total_amount);
    daily.set(key, entry);
  }

  return (
    <div className="space-y-4">
      <div className="grid md:grid-cols-4 gap-4">
        <div className="panel">
          <p className="text-xs text-gray-500">Staatskasse</p>
          <p className={`text-xl font-semibold ${(data.treasury?.balance ?? 0) < 50000000 ? 'text-red-400' : 'text-white'}`}>
            {formatMoney(data.treasury?.balance)}
          </p>
          <p className="text-[10px] text-gray-600">leere Kasse = keine Staatslöhne</p>
        </div>
        <div className="panel">
          <p className="text-xs text-gray-500">Geldmenge gesamt (M1)</p>
          <p className="text-xl font-semibold text-white">{formatMoney(m1)}</p>
        </div>
        <div className="panel">
          <p className="text-xs text-gray-500">Spieler (Bar / Bank)</p>
          <p className="text-sm text-white">{formatMoney(supply.playerCash)}<br />{formatMoney(supply.playerBank)}</p>
        </div>
        <div className="panel">
          <p className="text-xs text-gray-500">Firmenkonten</p>
          <p className="text-xl font-semibold text-white">{formatMoney(supply.companyFunds)}</p>
        </div>
      </div>

      <div className="panel overflow-x-auto">
        <h2 className="font-semibold text-white mb-2 text-sm">Quelle-Senke-Bilanz (14 Tage) — Inflations-Indikator</h2>
        <table className="w-full">
          <thead><tr><th className="th">Tag</th><th className="th">Erschaffen</th><th className="th">Vernichtet</th><th className="th">Netto</th></tr></thead>
          <tbody>
            {Array.from(daily.entries()).map(([day, e]) => {
              const net = e.created - e.destroyed;
              return (
                <tr key={day}>
                  <td className="td">{day}</td>
                  <td className="td text-green-400">{formatMoney(e.created)}</td>
                  <td className="td text-red-400">{formatMoney(e.destroyed)}</td>
                  <td className={`td ${net > 0 ? 'text-yellow-400' : 'text-gray-300'}`}>
                    {net > 0 ? '+' : ''}{formatMoney(net)}
                  </td>
                </tr>
              );
            })}
            {daily.size === 0 && <tr><td className="td text-gray-500" colSpan={4}>Noch keine Daten (Aggregat läuft stündlich).</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="panel overflow-x-auto">
        <h2 className="font-semibold text-white mb-2 text-sm">Staatskassen-Bewegungen (letzte 50)</h2>
        <table className="w-full">
          <thead><tr><th className="th">Zeit</th><th className="th">Richtung</th><th className="th">Betrag</th><th className="th">Grund</th><th className="th">Stand danach</th></tr></thead>
          <tbody>
            {data.treasuryEvents.map((e, i) => (
              <tr key={i}>
                <td className="td whitespace-nowrap text-xs">{new Date(e.time).toLocaleString('de-DE')}</td>
                <td className={`td ${e.payload.direction === 'credit' ? 'text-green-400' : 'text-red-400'}`}>
                  {e.payload.direction === 'credit' ? '▲ Einnahme' : '▼ Ausgabe'}
                </td>
                <td className="td">{formatMoney(e.payload.amount)}</td>
                <td className="td text-xs">{e.payload.reason}</td>
                <td className="td">{formatMoney(e.payload.balanceAfter)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
