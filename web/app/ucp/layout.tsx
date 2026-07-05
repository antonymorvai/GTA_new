'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { href: '/ucp', label: 'Dashboard' },
  { href: '/ucp/whitelist', label: 'Whitelist-Bewerbung' },
  { href: '/ucp/tickets', label: 'Tickets & Reports' },
  { href: '/ucp/wahlen', label: 'Wahlen & Gesetze' },
];

export default function UcpLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div className="space-y-6">
      <div className="flex gap-2 border-b border-white/10 pb-3">
        {TABS.map((t) => (
          <Link key={t.href} href={t.href}
            className={`px-3 py-1.5 rounded-md text-sm ${
              pathname === t.href ? 'bg-accent text-white' : 'text-gray-400 hover:text-white'
            }`}>
            {t.label}
          </Link>
        ))}
      </div>
      {children}
    </div>
  );
}
