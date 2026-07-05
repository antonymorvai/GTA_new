export default function PrivacyPage() {
  return (
    <div className="max-w-2xl panel text-sm text-gray-300 space-y-3">
      <h1 className="text-xl font-semibold text-white">Datenschutzerklärung</h1>
      <p><strong>Verantwortlicher:</strong> [vor Livegang befüllen]</p>
      <p><strong>Verarbeitete Daten:</strong> Account-Daten (Benutzername, E-Mail,
      Passwort-Hash), Spiel-Identifier (Cfx-Lizenz, IP-Adressen), Spielverlaufsdaten
      (Positionen, In-Game-Aktionen, Chat/SMS) zur Betrugs- und Cheat-Prävention
      sowie zur Aufrechterhaltung eines fairen Spielbetriebs (Art. 6 Abs. 1 lit. f DSGVO).</p>
      <p><strong>Speicherdauer:</strong> Spielverlaufsdaten werden standardmäßig 90 Tage
      (Positionsdaten 30 Tage) aufbewahrt und danach automatisch gelöscht.</p>
      <p><strong>Deine Rechte:</strong> Auskunft, Berichtigung, Löschung, Einschränkung,
      Datenübertragbarkeit, Widerspruch — Anfrage an die oben genannte Adresse.
      Das technische Auskunfts- und Löschkonzept ist in <code>docs/operations.md</code> dokumentiert.</p>
    </div>
  );
}
