export default function RulesPage() {
  return (
    <div className="prose prose-invert max-w-3xl">
      <h1 className="text-2xl font-semibold text-white mb-4">Regelwerk (v1)</h1>
      <div className="panel space-y-4 text-sm text-gray-300">
        <section>
          <h2 className="font-semibold text-white">§1 Grundsätze</h2>
          <p>Hardcore-RP: Dein Charakter ist eine eigenständige Person. Metagaming,
          Powergaming und RDM/VDM führen zu Sanktionen. IC-Handlungen haben IC-Konsequenzen.</p>
        </section>
        <section>
          <h2 className="font-semibold text-white">§2 Charaktere & Tod</h2>
          <p>Pflicht-Lebenslauf, 3 Charakter-Slots. Der endgültige Tod (CK) erfolgt nur
          per Antrag oder Medic-Entscheid — Bewusstlosigkeit ist der Normalfall.</p>
        </section>
        <section>
          <h2 className="font-semibold text-white">§3 Kriminalität</h2>
          <p>Verbrechen brauchen RP-Substanz. Jede Tat kann Spuren hinterlassen —
          die Polizei ermittelt mit echten Daten (Beweismittelketten, Seriennummern).</p>
        </section>
        <p className="text-xs text-gray-500">
          Das vollständige, versionierte Regelwerk mit Changelog wird hier vom
          Team gepflegt (CMS-Anbindung folgt).
        </p>
      </div>
    </div>
  );
}
