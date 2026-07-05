'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV = [
  { href: '/acp', label: 'Übersicht' },
  { href: '/acp/players', label: 'Spieler' },
  { href: '/acp/logs', label: 'Log-Explorer' },
  { href: '/acp/trace', label: 'Item-Trace & Geldfluss' },
  { href: '/acp/anomalies', label: 'Anomalie-Queue' },
  { href: '/acp/tuning', label: 'Live-Tuning' },
];

export default function AcpLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div className="grid grid-cols-[200px_1fr] gap-6">
      <aside className="space-y-1">
        {NAV.map((item) => (
          <Link key={item.href} href={item.href}
            className={`block px-3 py-2 rounded-md text-sm ${
              pathname === item.href ? 'bg-accent text-white' : 'text-gray-400 hover:text-white'
            }`}>
            {item.label}
          </Link>
        ))}
        <p className="text-[10px] text-gray-600 pt-4 px-3">
          Jeder Zugriff wird auditiert (admin.access).
        </p>
      </aside>
      <section>{children}</section>
    </div>
  );
}
