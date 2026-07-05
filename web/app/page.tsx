import Link from 'next/link';

const FEATURES: Array<{ title: string; text: string }> = [
  { title: 'Totale Nachverfolgbarkeit', text: 'Jede Aktion hinterlässt Spuren — Ermittlungen, Beweismittelketten und Gerichtsprozesse basieren auf echten Daten statt Behauptungen.' },
  { title: 'Dynamische Wirtschaft', text: 'Preise folgen Angebot und Nachfrage. Überfarmte Ressourcen erschöpfen, Märkte reagieren, nichts ist statisch.' },
  { title: 'Hardcore-Medizin', text: 'Trefferzonen, Blutungen, Bewusstlosigkeit statt Respawn. Der Rettungsdienst entscheidet, nicht der Respawn-Timer.' },
  { title: 'Echte Justiz', text: 'Versioniertes Gesetzbuch, Bußgelder, Haft, Fahndungen — Gesetze werden in-RP von der Justiz geändert.' },
  { title: 'Lebendige Unterwelt', text: 'Territorien mit kontinuierlichem Einfluss, mehrstufige Drogenketten, rotierende Deal-Spots — und jede Tat kann Spuren hinterlassen.' },
  { title: 'World Director', text: 'Unfälle, Ressourcen-Booms und Ereignisse entstehen ohne Admin-Eingriff — die Welt lebt auch ohne Drehbuch.' },
];

export default function Home() {
  return (
    <div className="space-y-12">
      <section className="text-center py-16">
        <h1 className="text-4xl font-bold text-white">
          Hardcore<span className="text-accent">RP</span>
        </h1>
        <p className="mt-4 text-lg text-gray-400 max-w-2xl mx-auto">
          GTA5-Roleplay mit maximalem Realismus: server-autoritativ, dynamische
          Spielwelt, Whitelist. Dein Charakter hat genau ein Leben pro Geschichte.
        </p>
        <div className="mt-8 flex justify-center gap-4">
          <Link href="/register" className="btn">Jetzt bewerben</Link>
          <Link href="/regelwerk" className="btn-ghost">Regelwerk lesen</Link>
        </div>
      </section>

      <section className="grid md:grid-cols-3 gap-4">
        {FEATURES.map((f) => (
          <div key={f.title} className="panel">
            <h2 className="font-semibold text-white">{f.title}</h2>
            <p className="mt-2 text-sm text-gray-400">{f.text}</p>
          </div>
        ))}
      </section>
    </div>
  );
}
