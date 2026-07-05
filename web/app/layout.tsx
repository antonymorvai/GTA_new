import type { Metadata } from 'next';
import Link from 'next/link';
import './globals.css';

export const metadata: Metadata = {
  title: 'HardcoreRP – GTA5 Roleplay',
  description: 'Hardcore-Roleplay-Server für GTA V: maximaler Realismus, dynamische Spielwelt.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body>
        <header className="border-b border-white/10">
          <nav className="max-w-6xl mx-auto flex items-center gap-6 px-4 py-3 text-sm">
            <Link href="/" className="font-semibold text-white">
              Hardcore<span className="text-accent">RP</span>
            </Link>
            <Link href="/regelwerk" className="hover:text-white">Regelwerk</Link>
            <Link href="/zeitung" className="hover:text-white">Zeitung</Link>
            <span className="flex-1" />
            <Link href="/ucp" className="hover:text-white">UCP</Link>
            <Link href="/acp" className="hover:text-white">ACP</Link>
            <Link href="/login" className="btn-ghost">Anmelden</Link>
          </nav>
        </header>
        <main className="max-w-6xl mx-auto px-4 py-8">{children}</main>
        <footer className="border-t border-white/10 mt-16">
          <div className="max-w-6xl mx-auto px-4 py-6 text-xs text-gray-500 flex gap-6">
            <span>© HardcoreRP</span>
            <Link href="/impressum" className="hover:text-gray-300">Impressum</Link>
            <Link href="/datenschutz" className="hover:text-gray-300">Datenschutz</Link>
          </div>
        </footer>
      </body>
    </html>
  );
}
