# HardcoreRP — Die vollständige Roadmap

> **Ziel: Der ultimative Hardcore-RP-Server.** So realistisch wie möglich, so
> dynamisch wie möglich, so modern wie möglich. Dieses Dokument ist der
> Gesamtplan — jede Verschönerung, Optimierung, Veränderung und Ergänzung.
>
> Status-Legende: ✅ umgesetzt · 🔨 in Arbeit · 🔜 geplant (H1–H3 = Horizont)

---

## 0. Design-Verfassung (aus der Community-Recherche destilliert)

Die Community sagt es deutlich (Reddit, Medium-Essays, Server-Vergleiche):

| Was Spieler frustriert / sich wünschen | Unsere Antwort — und die bessere Idee |
|---|---|
| „Geld-pro-Minute-Grind zwingt Charaktere in unrealistisches Verhalten — Cops gehen fischen, weil es mehr zahlt" | **RP ist die Belohnung, nicht der Kontostand.** Einkommen degressiv gestalten (Ermüdungs-Malus auf repetitive Tätigkeit), Fixkosten (Miete, Versicherung, Steuern) statt Reichtums-Wettrennen, Vermögenssteuer ✅. Neu: **„Lebensqualität"-Score statt Geld-Leaderboard** — Charaktere mit Wohnung, Job, Hobbys, sozialen Kontakten bekommen RP-Perks (schnellere Regeneration, Stress-Resistenz), nicht Geld. |
| „Alle strömen zum profitabelsten Job" | Dynamische Preise ✅ erledigen das ökonomisch — Überangebot senkt Löhne/Preise automatisch. Neu: **Bedarfs-Board** im UCP zeigt, wo die Stadt gerade Menschen braucht (zu wenige Medics? Bonus-Modifikator steigt sichtbar). |
| „Wirtschaft ist Fassade, Businesses sind Kulissen" | Interdependenz ist unser Kern: Tankstellen-Lieferketten ✅, Firmenkonten ✅, Staatskasse ✅. Ausbau: **jede Ware physisch bewegt** (H2). |
| „Regierung/Gesetze sind Deko" | Gesetzgebung mit echtem Inkrafttreten ✅, Wahlen ✅, Staatskasse zahlt Löhne ✅. Ausbau: Budget-Verhandlungen, Referenden, Amtsenthebung (H2). |
| „Worker-to-Owner-Pipeline & Progression wie NoPixel 4.0" | Skills ✅, Firmen ✅. Neu: **Karriere-Leitern in jedem Job** (Azubi → Meister → Inhaber mit übertragbarem Betrieb), **Crew-Tech-Trees** für Gangs (H2). |
| „Regelbrecher & schlechte Ermittlungs-Grundlagen" | Totale Nachverfolgbarkeit ✅ (Kill-Akte, Item-Trace, Replay). Neu: **In-RP-Beweise first** — OOC-Reports brauchen Log-Permalinks ✅, Richter bekommen kuratierte Beweismappen (H1). |
| „Moderne, minimale UIs statt 2015-Menüs" | Design-System „Nebula" (unten, §L): dunkel-transparent, eine Akzentfarbe, Inter/Geist-Font, Micro-Animationen, alles NUI — kein natives GTA-Menü irgendwo. |
| „FOMO & 20-h-Grind schadet Gesundheit" | **Diminishing Returns pro Tag** auf alle Einkommensquellen + „Müdigkeit"-Vital ✅ (Ausbau: Schlaf-Mechanik H1) — der 20-h-Grinder verdient ab Stunde 6 fast nichts mehr, der 2-h-Abend-Spieler ist gleichwertig. |

**Fünf unverhandelbare Prinzipien** (gelten für jeden Punkt dieser Roadmap):
1. **Server-autoritativ & vollständig geloggt** — kein Feature ohne Event-Katalog-Eintrag.
2. **Dynamisch statt statisch** — jeder Wert reagiert auf Spielerverhalten, jede Stellschraube ist live tunebar.
3. **Konsequenz statt Strafe** — Systeme erzeugen In-RP-Folgen (Spuren, Schulden, Ruf), OOC-Sanktionen sind das letzte Mittel.
4. **RP ist die Belohnung** — Design belohnt Geschichten, nicht Stunden.
5. **Modern by default** — jede Oberfläche folgt dem Nebula-Design-System, jede Interaktion hat Feedback (< 100 ms).

---

## A. Charakter & Immersion

- ✅ Multi-Charakter (3 Slots), Pflicht-Lebenslauf, Vitals (Hunger/Durst/Stress), Skills mit Decay, Sucht-System
- 🔜 H1 **Charaktererstellung 2.0**: voller Freemode-Editor als NUI (Erbe/Blend, alle Overlays, Kleidung), Vorschau-Drehbühne, Presets speichern
- 🔜 H1 **Schlaf & Müdigkeit**: Müdigkeits-Vital aktiv — schlafen in Bett (eigene Wohnung = voller Bonus, Motel = teilweise); Übermüdung = Stamina-/Fahr-Malus, Mikroschlaf-Blackscreen (1 s) als spürbares Risiko
- 🔜 H1 **Hygiene & Temperatur aktiv**: Duschen (Wohnung/Gym), Schwitzen/Frieren nach Wetter+Kleidung, Unterkühlung im Winter-Regen → Erkältung (Husten-Emotes, Medikamente)
- 🔜 H1 **Emote-/Animations-Suite**: 300+ Emotes mit Suche (NUI-Rad), Props (Kaffee, Zigarette, Klemmbrett), synchronisierte Paar-Emotes (Handschlag, Umarmung, Tanzen), sitzen/lehnen überall
- 🔜 H1 **Walkstyles & Stimmungs-Ausdruck**: Gangart wählbar + automatisch von Vitals beeinflusst (verletzt humpeln ✅-nah, betrunken torkeln, müde schlurfen)
- 🔜 H2 **Aussehen altert**: Narben aus schweren Verletzungen (Positions-genau), graue Haare mit Spielzeit-Jahren, Gewicht ändert sich mit Ernährung
- 🔜 H2 **Lebensqualitäts-Score**: Wohnung + Job + Hobby + Sozialkontakte (gemeinsame RP-Zeit) → Perks (Stress-Resistenz, Regeneration); ersetzt Geld als Statusmaß
- 🔜 H2 **Charakter-Tagebuch**: automatische Chronik („Heute kennengelernt: …", „Erster Arbeitstag bei …") aus Events generiert, im UCP als erzählbare Timeline — die eigene Geschichte lesbar
- 🔜 H2 **Hobbys mit Substanz**: Fitness (Gym-Progression → Stamina-Skill), Fotografie (Foto-Items als Beweis/Kunst), Musikinstrumente (synchronisierte Straßenmusik + Trinkgeld), Kartenspiele/Schach als Multiplayer-Minigames in Kneipen
- 🔜 H3 **Erbe & Generationen**: bei CK kann ein Nachfolge-Charakter definiertes Erbe antreten (Testament beim Anwalt, Erbschaftssteuer) — Familiendynastien über Charaktertode hinweg
- 🔜 H3 **Haustiere**: Hund/Katze als Begleiter (Futter-Bedarf, Tierarzt-Job-Anbindung, K9 für Polizei)

## B. Medizin & Rettungsdienst

- ✅ Trefferzonen, Blutung, Bewusstlosigkeit statt Respawn, Krankenakten, Klinikkosten, EMS-Revive/Diagnose
- 🔜 H1 **Verletzungs-Folgen spürbar**: Beinfraktur = humpeln/kein Sprint bis behandelt, Armfraktur = keine Waffe/kein schweres Tragen, Reha-Debuff-Phase mit sichtbarem Fortschritt im HUD
- 🔜 H1 **Behandlungs-Gameplay**: Diagnose-NUI (Körper-Silhouette mit markierten Zonen), Behandlung als kurze Skill-Minigames (Druckverband anlegen, Schienen), Triage-Farben bei Großlagen
- 🔜 H2 **OP-System**: schwere innere Verletzungen brauchen OP im Krankenhaus (mehrstufige Interaktion, 2 Medics, OP-Saal-Ressource), OP-Berichte in der Krankenakte
- 🔜 H2 **Blutkonserven-Wirtschaft**: dynamischer Bestand, Blutspende-Aktionen (Director-Event bei Knappheit), Blutgruppen je Charakter
- 🔜 H2 **Medikamente & Rezepte**: Schmerzmittel mit Abhängigkeitsrisiko (Sucht-System ✅ andocken), Rezeptpflicht (Arzt stellt aus, Apotheke löst ein, Rezept-Item mit Fälschungsrisiko)
- 🔜 H2 **Psychologie**: Stress-Therapie beim Psychologen (Spieler-Job!), Trauma-Debuffs nach schweren Downs, Therapie-Gespräche als geschützter RP-Raum
- 🔜 H3 **Seuchen-Events**: Director-gesteuerte Krankheitswellen (Symptom-Emotes, Ansteckung über Nähe, Test/Impf-Kampagnen als stadtweite RP-Arcs)
- 🔜 H3 **Organspende & Ethik-RP**: Spenderausweis-Item, Transplantations-Wartelisten — schwerer, erwachsener RP-Stoff für Medic/Justiz-Crossover

## C. Polizei & Ermittlung

- ✅ MDT-Datenbasis (Access-geloggt), Strafregister, Fahndungen, Beweismittelkette, Seriennummern-Ballistik, /wanted, Dispatch
- 🔜 H1 **MDT als NUI-Tablet**: modernes Interface (Nebula), Personen-/Fahrzeug-/Waffenakten, Fahndungs-Board mit Fotos, Fall-Verknüpfungen, Streifen-Status
- 🔜 H1 **Spurensicherung am Tatort**: Patronenhülsen (Serien-Ballistik ✅ nutzt es), Blutproben (→ Charakter-DNA), Fingerabdrücke auf Items (metadata ✅ vorbereitet), Lackspuren bei Unfallflucht; Spuren-Kit-Item, Laborauswertung mit Wartezeit
- 🔜 H1 **Bodycams & Dashcams**: automatische „Aufnahme" = markierter Log-Zeitraum, im MDT als Beweis-Permalink an Akten heftbar (nutzt Replay-Daten ✅ — besser als Video: durchsuchbar)
- 🔜 H1 **Cuff/Escort/Durchsuchung**: saubere Anims, Durchsuchung zeigt Inventar (mit Rechtsgrundlagen-Abfrage, geloggt ✅-Muster), Beschlagnahme direkt in Beweis-Container
- 🔜 H2 **Funkzellen & TKÜ mit richterlichem Beschluss**: Workflow Richter → Freischaltung → Polizei sieht Telefon-Metadaten/Standort für Zeitraum X (jeder Zugriff auditiert), SMS-Inhalte nur mit erweitertem Beschluss
- 🔜 H2 **Verdeckte Ermittler**: Tarn-Identität im System (MDT zeigt Legende statt echter Akte), Aufdeckungs-Risiko-Mechanik
- 🔜 H2 **Ermittlungsdruck-System**: Wer viele Straftaten begeht, sammelt „Heat" — mehr Zeugen-NPCs, höhere Spuren-Chancen, Kamera-Treffer; Heat verfällt bei Ruhe (verzahnt mit crime.trace ✅)
- 🔜 H2 **CCTV-Netz**: Kameras an Läden/Kreuzungen — Polizei kann mit Beschluss „Aufnahmen sichten" = Replay-Ausschnitt des Kamera-Radius (Datenbasis ✅ vorhanden!)
- 🔜 H2 **SWAT & Großlagen**: Ausrüstungs-Stufen, Geisel-Verhandlungs-Mechanik (Telefon-Anbindung), Einsatzleiter-Rolle mit Live-Karte
- 🔜 H3 **Kriminalanalyse-Dashboard**: die ACP-Heatmap ✅ als In-RP-Tool fürs Präsidium — Deliktschwerpunkte, Streifenempfehlungen (aus echten Daten, zeitversetzt um Metagaming zu vermeiden)

## D. Justiz, Regierung & Verwaltung

- ✅ Versioniertes Gesetzbuch, Gesetzgebungs-Workflow, Wahlen (geheim), Bußgelder, Haft mit Geofence, Staatskasse
- 🔜 H1 **Gerichtsverhandlungen**: Termin-System (UCP-Kalender), Gerichtssaal-Rollen (Richter/StA/Verteidigung/Zeugen), Beweismappen aus Log-Permalinks kuratiert, Urteils-Dokumente
- 🔜 H1 **Anwalts-Ökonomie**: Mandats-Verträge, Akteneinsicht rollenbasiert (Verteidiger sieht Anklage-Beweise), Pflichtverteidiger-Pool
- 🔜 H2 **Haft mit Inhalt**: Resozialisierungs-Jobs (Wäscherei, Bibliothek → Haftzeit-Verkürzung), Hofgang-Zeiten, Besuchersystem, Schmuggel-Risiko (Einbring-Mechanik)
- 🔜 H2 **Bewährung & Fußfessel**: Auflagen-Tracking (Geofence-Alarm an Polizei ✅-Muster), Bewährungshelfer-Termine, Widerruf-Workflow
- 🔜 H2 **Pfändung & Insolvenz**: Justiz kann Konten sperren/pfänden (Kredit-Ausfälle ✅ liefern Anlässe), Privatinsolvenz mit Wohlverhaltensphase, Firmen-Insolvenzverfahren mit Verwalter
- 🔜 H2 **Haushalts-Politik**: Regierung verabschiedet Budgets pro Fraktion (Polizei-Ausrüstung kostet!), Staatskasse ✅ wird verteilt, Rechnungshof-Berichte automatisch aus Events
- 🔜 H2 **Referenden & Amtsenthebung**: Bürgerbegehren (Unterschriften-Mechanik), Misstrauensvotum gegen den Governor
- 🔜 H3 **Verwaltungs-Ämter**: Bürgeramt (Ausweise, Umzug/Meldeadresse), Zulassungsstelle (Wunschkennzeichen, HU-Termine), Standesamt (Ehen mit Güterrecht!, Namensänderung)
- 🔜 H3 **Notariat**: Verträge zwischen Spielern als signierte Dokumente (Kauf, Miete, Kredit privat) — einklagbar vor Gericht, weil beweisbar

## E. Wirtschaft, Firmen & Anti-Grind

- ✅ Dynamische Preise, Staatskasse, Steuern (Einkommen/Vermögen), Firmen mit Konten & Lohnlauf, Kredite mit Bonität, Lieferketten (Kraftstoff)
- 🔜 H1 **Diminishing Returns überall**: jede Einkommensquelle hat Tages-Sättigung (erste 2 h voll, dann degressiv) — der Anti-Grind-Kern; im HUD dezent sichtbar („Erschöpft für heute")
- 🔜 H1 **Fixkosten-Realismus**: Miete, Strom (Immobilie), Versicherungen ✅, Handyvertrag — Geld muss ARBEITEN, ein Kontostand ohne Ausgaben ist kein Erfolg
- 🔜 H1 **Bedarfs-Board (UCP)**: „Die Stadt braucht: 2 Medics, 1 Richter, Kraftstoff Nord" — aus echten Daten (Dienstplan-Lücken, Stations-Bestände ✅), mit dynamischen Bonus-Modifikatoren
- 🔜 H2 **Alle Waren physisch**: Shops erhalten Ware per Spieler-Lieferung (Lieferketten-Muster ✅ generalisiert auf Lebensmittel/Werkzeug), Großmarkt als Drehkreuz, Diebstahl ganzer Lieferungen möglich
- 🔜 H2 **Worker-to-Owner-Pipeline**: jeder Betrieb (Werkstatt, Shop, Taxi) kann von Angestellten hochgedient und ÜBERNOMMEN werden (Kauf/Übergabe mit Vertrag), Betriebs-Reputation wandert mit
- 🔜 H2 **Firmen-Tiefe**: Zeichnungsberechtigungen, Kassenbuch-NUI (aus money-Events ✅ generiert), Betriebsprüfung durchs Finanzamt (Anomalie-Regeln ✅ als In-RP-Anlass), Firmenübernahmen/Fusionen
- 🔜 H2 **Börsenticker & Zeitung-Wirtschaftsteil**: Preisindizes aus economy.price_tick ✅ als In-Game-App + automatische Marktberichte in der Zeitung ✅
- 🔜 H2 **Auktionshaus**: Zwangsversteigerungen (Pfändung), Oldtimer-Auktionen, Kunst — Live-Auktions-NUI mit Bieter-Anonymität
- 🔜 H3 **Import/Export-Hafen**: Container-Wirtschaft am Hafen (legale Importe mit Zoll-Kontrolle = Zoll-Fraktion, Schmuggel als Schattenseite)
- 🔜 H3 **Gewerkschaften & Tarif-RP**: Angestellten-Organisation, Streik-Mechanik (Betriebe stehen still), Tarifverhandlungen mit echten Lohn-Folgen

## F. Illegales & Unterwelt

- ✅ Drogenkette (Anbau→Verarbeitung→rotierende Spots), Territorien mit Einfluss-Verfall, Hehler, Spuren-System, Geldtransport-Raub, Sucht
- 🔜 H1 **Waffenschmuggel-Kette**: Teile-Lieferungen (Hafen/Grenze) → illegale Werkbank (Waffen OHNE Seriennummer bzw. angefeilt — aber unvollständig entfernbar: Ballistik-Rest bleibt als Ermittlungsansatz ✅-Anschluss)
- 🔜 H1 **Raub-Stufen**: Ladendiebstahl → Tankstellen-Raub → Juwelier → Bank-Filiale → Staatsbank (Crew-Größe, Cop-Mindestzahl dynamisch ✅-Muster, Werkzeug-Anforderungen, Verhandlungs-Phase mit Geiseln)
- 🔜 H1 **Auto-Zerlege-Ring**: bestellte Modelle (dynamische Order-Liste), Zerlege-Werkstatt (Teile als Items → Hehler/Schwarzmarkt), VIN-Prüfung ✅-Anschluss macht gestohlene Teile heiß
- 🔜 H2 **Drogen-Qualitätsstufen & Streckung**: Streckmittel erhöhen Menge, senken Qualität — schlechter Stoff schädigt Kunden (Medic-Einsätze!) und den Dealer-RUF
- 🔜 H2 **Straßen-Reputation**: Unterwelt-Ruf pro Charakter (aus Taten, nicht Grind) — schaltet Kontakte frei (bessere Hehler-Preise, Aufträge), sinkt bei Snitching/Festnahmen
- 🔜 H2 **Crew-Tech-Tree**: Gangs schalten Fähigkeiten frei (bessere Verstecke, Störsender-Zugang, Fluchtrouten-Kenntnis) über Aktivität — Progression statt Grind (NoPixel-4.0-Lehre, besser: Baum verfällt bei Inaktivität wie Territorien ✅)
- 🔜 H2 **Schutzgeld & Fronten**: Betriebe können „Schutz" zahlen (oder Polizei einschalten → verdeckte Ermittlung), Geldwäsche über eigene Läden mit Aufdeckungs-Risiko (Anomalie ✅ als Finanzamt-Trigger)
- 🔜 H2 **Entführungen & Lösegeld**: strukturierte Mechanik (Verhandlung übers Telefon, Übergabe-Punkte, Peilsender-Risiko im Geldkoffer)
- 🔜 H3 **Illegale Kämpfe & Untergrund-Casino**: Fight Club mit Wett-System, Poker-Runden (echtes Multiplayer-Poker-NUI), Razzia-Risiko
- 🔜 H3 **Kronzeugen-Programm**: Aussage gegen die eigene Organisation (Justiz-Deal-Workflow) — Hochverrats-RP mit Zeugenschutz-Mechanik (neue Identität = dokumentierter Charakter-Rebrand)

## G. Fahrzeuge & Verkehr

- ✅ Kraftstoff (echte Bestände), Verschleiß + Wartung, Tuning, Kofferraum, Versicherung + Totalschaden, Blitzer, Schlüssel, Kilometerstand
- 🔜 H1 **Fahrzeug-Aufbrechen**: Dietrich-Minigame (Skill-basiert ✅-Muster), Alarmanlagen-Stufen, Wegfahrsperre (Hotwire vs. Schlüssel-Klau), gestohlene Fahrzeuge im MDT
- 🔜 H1 **HU/TÜV**: Prüftermin (Verkehrsamt/Werkstatt), Prüfprotokoll aus echten Zustandsdaten (Verschleiß ✅), abgelaufene Plakette = Bußgeld-Tatbestand
- 🔜 H1 **Handling-Realismus**: Motor-Warmlauf, Reifenplatzer bei Verschleiß, Batterie leer bei Standlicht — kleine Systeme, große Immersion
- 🔜 H2 **Gebrauchtmarkt**: Spieler-zu-Spieler-Verkauf mit Kaufvertrag-Item (Notariat-Anschluss), Fahrzeughistorie einsehbar (Unfälle/Tachostand aus Events ✅ — Tacho-Betrug unmöglich, ein Alleinstellungsmerkmal!)
- 🔜 H2 **Leasing & Import-Wartelisten**: Händler-Bestand ✅ erweitert: seltene Modelle nur per Warteliste/Import (Hafen-Anschluss), Leasing mit Rückgabe-Zustandsprüfung
- 🔜 H2 **Punktesystem & Führerscheinentzug**: Verkehrs-Punkte aus Bußgeldern ✅, Entzug + Nachschulung (Fahrschul-Job!), Fahren ohne = Straftat
- 🔜 H2 **Öffentlicher Verkehr**: Bus-Linien (Spieler-Fahrer, NPC-Fahrgast-Nachfrage dynamisch nach Stadtteil-Aktivität), Taxi mit App-Bestellung (Phone-App), Bahn als Schnellreise mit Ticket
- 🔜 H2 **Parkraum & Abschleppen**: Halteverbote, Abschlepp-Job (Mechaniker-Anschluss), Verwahrhof mit Auslöse-Gebühr
- 🔜 H3 **Renn-Szene**: illegale Straßenrennen (Checkpoint-System, Wetten, Heat ✅-Anschluss) vs. legale Track-Days (Verein, Zeitmesslisten)
- 🔜 H3 **Luft & See**: Flugschein-Ausbildung (Theorie im UCP!, Praxis-Prüfer-Job), Charter-Business, Hafen-Bootsverkehr, Küstenwache-Unterfraktion

## H. Immobilien & Housing

- ✅ Kauf, dynamische Preise, Routing-Bucket-Interiors, Schlüssel, Lager, Einbruch
- 🔜 H1 **Interior-Vielfalt**: 10+ Shell-Typen (Apartment/Haus/Villa/Lager/Büro) statt Einheits-Motel, MLO-Integration wo verfügbar
- 🔜 H1 **Möbel-System**: Platzierungs-Editor (NUI, Raster + freie Rotation), Möbel als Items (Kauf im Möbelhaus = neuer Betrieb!), Deko wirkt auf Lebensqualitäts-Score
- 🔜 H2 **Miete & Nebenkosten**: Mietverträge (Eigentümer ↔ Mieter, Notariat), Strom-/Wasser-Abschlag, Zahlungsverzug → Räumungsklage (Justiz-Workflow)
- 🔜 H2 **Alarmanlagen-Stufen**: Basis (Chance ✅) → Silent-Alarm (direkter Dispatch) → Kamera (CCTV-Anschluss) — Einbruchs-Meta bleibt dynamisch
- 🔜 H2 **Lage-Score aus echten Daten**: Kriminalitätsrate (crime-Events im Radius!), Territoriums-Nähe, ÖPNV-Anbindung → fließt live in current_price — der Immobilienmarkt ATMET mit der Stadt
- 🔜 H2 **WG & Untervermietung**: mehrere Mieter, geteilte Kosten, Mitbewohner-Rechte-Stufen
- 🔜 H3 **Immobilien-Entwicklung**: Makler-Fraktion kann Objekte renovieren (Wert-Steigerung), Regierung weist Neubau-Zonen aus (Bau-Firmen-Aufträge aus echtem Bedarf)

## I. Jobs, Hobbys & Freizeit

- ✅ Jobs-Gerüst (Duty, Löhne aus Staatskasse), Trucker-Lieferkette, Ressourcen-Jobs (Fischen/Bergbau/Holz/Farming saisonal), Crafting mit Werkbänken, Journalist
- 🔜 H1 **Job-Onboarding**: jede Tätigkeit hat ein 5-Minuten-Tutorial-RP (NPC-Vorarbeiter-Dialog), Ausrüstungs-Ausgabe, erste-Schritte-Checkliste im HUD
- 🔜 H1 **Müllabfuhr & Stadtreinigung**: Routen aus echtem „Müll" (Bodendrops ✅ vor Despawn einsammeln = bezahlt!), Stadt-Sauberkeits-Index sichtbar
- 🔜 H2 **Landwirtschaft komplett**: Felder pachten, Saat → Pflege → Ernte (Saison ✅), Bewässerung bei Hitze, Verkauf an Großmarkt (Warenkette), Viehzucht
- 🔜 H2 **Jagd mit Populations-Simulation**: Wild-Bestände als Pools ✅-Muster mit Wander-Verhalten, Jagdschein, Trophäen/Fleisch-Kette, Wilderei als Straftat
- 🔜 H2 **Fischerei-Tiefe**: Fangquoten (Regierung!), Bootsfischen mit Netz, Fischmarkt-Auktion morgens (dynamischer Preis nach Anlandung)
- 🔜 H2 **Bauwesen**: Baustellen aus Regierungs-/Firmen-Aufträgen (Material-Lieferketten!), Gerüst/Kran-Interaktionen, Bauabnahme
- 🔜 H2 **Gastronomie**: Restaurants/Bars als Betriebe mit ECHTEN Rezepten (Zutaten aus Landwirtschaft/Markt), Buff-Food (Qualität ✅-Anschluss), Lieferdienst-App
- 🔜 H3 **Events-Freizeit**: Kino (synchronisierte Videos), Bowling/Darts/Golf-Minigames, Vergnügungspark-Betrieb, Paintball-Arena (Kampf-Training ohne Konsequenz)
- 🔜 H3 **Sport-Ligen**: Boxen (legal, Verband!), Streetball, Renn-Liga — Saisons mit Tabellen im UCP, Sponsoring durch Spieler-Firmen

## J. Kommunikation & Medien

- ✅ SMS, Twitter-Klon, Kleinanzeigen, Funk mit Staatskanälen, Zeitung (in-game + Web)
- 🔜 H1 **Smartphone 2.0 (NUI)**: echtes Phone-Interface (Nebula-Design) — Homescreen, Apps: Kontakte/SMS-Threads, Banking ✅-Anschluss, Twitter-Feed, Anzeigen-Markt, Kamera, GPS mit Pins, Einstellungen (Klingelton, Flugmodus!)
- 🔜 H1 **Anrufe mit Voice-Routing**: SaltyChat-Telefonie (Brücke ✅ vorbereitet), Anruf-UI, Mailbox, Konferenz für Fraktionen
- 🔜 H1 **Kamera & Beweisfotos**: Foto = Item mit Metadaten (Ort/Zeit — manipulierbar nur mit Skill = Fälschungs-RP), Galerie, an Tickets/Akten anhängbar
- 🔜 H2 **Darknet**: verborgene App (Zugang über Item/Kontakt), Schwarzmarkt-Listings, Krypto-Analogie-Währung (eigener Kurs, dynamisch!), Ermittlungs-Gegenstück (Cyber-Crime-Einheit)
- 🔜 H2 **Radio-Sender**: Spieler-DJ-Slots (Audio-Streams), Werbespots von Firmen (bezahlt!), Nachrichten zur vollen Stunde (aus Zeitungs-Artikeln generiert)
- 🔜 H2 **Zeitungs-CMS 2.0**: Redaktions-Workflow im UCP (Entwurf → Chefredakteur-Freigabe), Ausgaben mit Auflage = echte In-Game-Verkäufe (Kiosk!), Anzeigen-Geschäft, Archiv
- 🔜 H2 **IMEI & Handy-Ortung**: Handys ✅ ortbar nur mit richterlichem Beschluss (TKÜ-Workflow), gestohlene Handys: SIM-Tausch beim Hehler
- 🔜 H3 **Streaming-Persona in-game**: „Lifeinvader-Live" — Charaktere können in-game streamen (Zuschauer-NPCs + echte Spieler), Fame-Mechanik mit Werbeverträgen

## K. Welt-Dynamik & Atmosphäre

- ✅ World Director (Spots, Booms, Unfälle, Geldtransport), Wetterfronten + Jahreszeiten, Territorien, Ressourcen-Pools, dynamische Preise
- 🔜 H1 **NPC-Dichte nach Kontext**: Uhrzeit/Stadtteil/Territorium steuern Fußgänger-/Verkehrsdichte (Innenstadt nachts leerer, Grove bei Gang-Hochphase gemiedene Straßen)
- 🔜 H1 **Director-Erweiterung**: Brände (Feuerwehr-Fraktion!), Stromausfälle pro Stadtteil (Ampeln aus, Läden zu, Alarmanlagen tot — Einbruchs-Fenster!), Wildunfälle (Jagd-Anschluss), Falschfahrer
- 🔜 H2 **Feuerwehr-Fraktion**: dynamische Brände mit Ausbreitung (Gebäude-Zonen), Löschen als Team-Gameplay, Brandursachen-Ermittlung (Brandstiftung = Spuren!)
- 🔜 H2 **Küsten & Naturereignisse**: Stürme (Flug-/Bootsverbot, Schäden), Erdrutsche auf Landstraßen (Räum-Aufträge!), Hitzewellen (Wasser-Verbrauch ↑, Waldbrand-Risiko)
- 🔜 H2 **Lebendige Läden**: NPC-Öffnungszeiten, Nachtschalter-Logik, NPC-Verkäufer mit Dialog-Varianz (statt stummer Marker)
- 🔜 H2 **Welt-Reaktion auf Politik**: Steuersätze beeinflussen NPC-Konsum-Sounds/Deko (Wirtschaftskrise = Bettler-NPCs, Boom = Baustellen) — die Stadt ERZÄHLT den Zustand der Wirtschaft
- 🔜 H3 **Dynamische Map-Evolution**: Saison-Deko (Weihnachtsmarkt, Halloween), Bauprojekte verändern die Map über Monate (Fortschritt sichtbar), Denkmal für Server-Geschichte (CK-Gedenktafeln!)

## L. UI/UX In-Game — Design-System „Nebula"

> Ein System für ALLES: dunkel-transparent (rgba(10,14,22,0.92)), eine
> Akzentfarbe (Server-Blau #4f8cff), Inter/Geist-Typo, 8-px-Raster,
> Micro-Animationen (150 ms ease-out), Gamepad-/Keyboard-navigierbar,
> jede Interaktion < 100 ms Feedback. Kein natives GTA-Menü verbleibt.

- ✅ HUD (Vitals/Tank/Tacho/Uhr), Inventar-NUI, Charakterauswahl-NUI
- 🔜 H1 **HUD 2.0**: Vitals als minimale Ringe statt Balken, kontextuell ausblendend (Vollbild-Immersion wenn alles ok), Schadens-Richtungsindikator, Statuseffekt-Icons (verletzt/müde/high/überladen), Einstellbarkeit (Position/Skalierung im UCP-Profil)
- 🔜 H1 **Interaktions-System**: ein universeller „Dritte-Auge"-Interact (Taste + Blick-Raycast) mit radialen Kontext-Optionen — ersetzt ALLE /commands im Alltag (Befehle bleiben als Fallback)
- 🔜 H1 **Notification-System**: einheitliche Toasts (Position wählbar), Prioritätsstufen, Verlaufs-Panel (letzte 20), Fraktions-Alerts unterscheidbar
- 🔜 H1 **Progress & Minigames**: einheitliche Progressbar mit Cancel, Skill-Minigame-Bibliothek (Timing-Ring, Lockpick-Zylinder, Hack-Sequenz) — überall dieselbe Sprache
- 🔜 H1 **Inventar 2.0**: Grid mit Drag&Drop, Splitten per Slider, Hotbar (1–5), Container-seitig-an-seitig (Kofferraum/Lager-Transfer), Item-Tooltips mit Qualität/Metadaten, Gewichts-Ring
- 🔜 H2 **Fraktions-Interfaces**: MDT-Tablet (C), Medic-Tablet (Patienten-Übersicht), Mechaniker-Diagnose-Screen (Fahrzeugzustand visuell), Regierungs-Pult (Gesetze/Budget)
- 🔜 H2 **Sound-Design**: eigenes UI-Sound-Set (dezent), Atmo-Layer (Innenstadt/Natur), Herzschlag bei kritischem Zustand, Tinnitus nach Explosionen — Audio verkauft Härte besser als jedes HUD
- 🔜 H2 **Kontext-Immersion**: Betrunkenheits-Shader, Verletzungs-Vignette, Adrenalin-Zeitlupe (0,5 s) bei Beinahe-Tod, Kamera-Wackeln bei Müdigkeit — alle abschaltbar (Accessibility!)
- 🔜 H2 **Accessibility**: Farbenblind-Modi, Schriftgrößen, Reduced Motion, vollständige Controller-Unterstützung, Screenreader-Labels im UCP/ACP
- 🔜 H3 **Cinematics**: Charakter-Intro-Sequenz (erster Spawn = Ankunft mit Bus/Flugzeug, Kamerafahrt), CK-Abspann (Timeline der Charakter-Geschichte als Film) — Gänsehaut-Momente als Feature

## M. Website, UCP & ACP — Modern Web

- ✅ Homepage, Auth+2FA, Whitelist-Workflow, Tickets, UCP (Dashboard/Kontoauszug/Wahlen/Strafregister), ACP (Akte/Logs/Timeline/Trace/Geldfluss/Replay/Kill-Akte/Live-Map/Heatmap/Anomalien/Tuning/Wirtschaft/Sanktionen), Zeitung
- 🔜 H1 **Visual-Refresh „Nebula Web"**: Landing mit Video-Hero (Server-Footage), Glassmorphism-Panels, Framer-Motion-Übergänge, Light/Dark, durchgängige Komponenten-Bibliothek (shadcn-basiert)
- 🔜 H1 **Live-Statusseite**: Spielerzahl-Graph (24 h), Warteschlange, Restart-Timer, Fraktions-Stärken (im Dienst), Wirtschafts-Ticker öffentlich (Teaser)
- 🔜 H1 **UCP-Dashboard 2.0**: Charakter-Karten mit Portrait (Screenshot-Upload), Vermögens-Sparkline, Spielzeit-Kalender-Heatmap, „Dein Tag"-Zusammenfassung aus Events
- 🔜 H1 **WebSockets überall**: Live-Updates statt Polling (Tickets, Anomalien, Live-Map, Bewerbungsstatus mit Push)
- 🔜 H2 **Geldfluss als interaktiver Graph**: Force-Layout (D3), Zoom/Drag, Hop-Tiefe-Slider, Zeitfenster-Scrubbing, Verdachts-Pfade hervorheben, Export als Fall-Anhang
- 🔜 H2 **Replay 2.0**: echtes Kartenbild-Layer (Atlas-Tiles), Multi-Charakter-Replay (mehrere Pfade), Event-Marker klickbar auf dem Pfad, „Zur Kill-Akte springen"
- 🔜 H2 **Fall-Verwaltung (ACP)**: Reports/Alerts/Logs zu Fällen bündeln, Beweis-Board (Permalinks/Replays/Notizen), Zuweisung + Vier-Augen-Entscheidung, komplette Sanktions-Beschluss-Historie
- 🔜 H2 **Ban-Einspruch-Portal**: strukturierter Workflow (Frist, Stellungnahme, Vier-Augen ✅-Regel), Entscheidungs-Templates, Transparenz-Statistik öffentlich (Bans/Appeals/Quoten — Vertrauen durch Zahlen)
- 🔜 H2 **Team-Dashboard**: Dienstzeiten der Mods, Ticket-Response-SLAs, Sanktions-Konsistenz-Report (gleiche Tat ≈ gleiche Strafe?)
- 🔜 H2 **Fraktions-Portale im UCP**: Dienstpläne (Schicht-Kalender), interne Akten/Foren, Fuhrpark-Buchung, Rechte je Fraktions-Rang
- 🔜 H3 **Öffentliche Server-Chronik**: „Geschichte von Los Santos" — kuratierte Groß-Ereignisse (Wahlen, Prozesse, Kriege) als Zeitstrahl; neue Spieler verstehen die Welt, alte werden verewigt
- 🔜 H3 **Mobile-PWA**: UCP als installierbare App (Push für Gerichts-Termine, Gehaltseingang, Ticket-Antworten)

## N. Voice & Audio-Immersion

- ✅ Funk-Modul mit Frequenzen/Staatskanälen, SaltyChat-Brücke, Text-Fallback
- 🔜 H1 **SaltyChat produktiv**: TS-Server-Setup dokumentiert ✅ → live schalten, 3D-Distanz kalibrieren (Flüstern 2 m / Normal 8 m / Schreien 20 m), Telefonklang-Filter, Funk-Squelch
- 🔜 H2 **Umgebungs-Audio-Logik**: Musik-Boxen (Item, hörbar für Nähe), Club-Sound-Zonen, Megafon (Polizei), Störsender als Illegal-Item (Funk-Blackout im Radius — Heist-Taktik!)
- 🔜 H2 **Voice-Anonymisierung**: Sturmhauben-Stimmverzerrer (Item) — Stimme wiedererkennen als Ermittlungs-Element bleibt möglich (schwächer)
- 🔜 H3 **Positional-Detail**: Wände dämpfen, Telefon klingelt räumlich, Kofferraum-Muffling (Entführungs-RP!)

## O. Technik, Performance & Anti-Cheat

- ✅ Event-Pipeline (verlustfrei), Audit, Anti-Cheat-Basis (Teleport/Godmode/Entity/Explosion), Lasttest, CI, OpenAPI, Backups+PITR
- 🔜 H1 **Erster Live-Boot & Integrationstest** (Launch-Checkliste ✅) — der wichtigste Einzelpunkt der gesamten Roadmap
- 🔜 H1 **OneSync-Feintuning**: Entity-Culling-Radien, Slot-Skalierung 128→200+ testen, Ressourcen-`resmon`-Budget je Modul (< 0,5 ms Ziel) dokumentieren
- 🔜 H1 **Client-FPS-Pass**: NUI-Renderlast messen, HUD auf Canvas statt DOM-Updates, Texture-Budget für NUIs
- 🔜 H2 **Anti-Cheat 2.0**: Server-seitige Waffen-Whitelist (equipped ✅ vs. tatsächliche Ped-Waffe abgleichen), Damage-Modifier-Detection, Statistik-Profile je Spieler (Headshot-Rate, TTK) → Anomalie-Queue, Honeypot-Events für Cheat-Menüs
- 🔜 H2 **Observability**: Prometheus-Metriken (Events/s, Queue-Lag, Tick-Zeiten), Grafana-Dashboards, Alerting → Discord ✅-Kanal
- 🔜 H2 **Blue/Green-Deploys**: Ressourcen-Hot-Reload-Strategie, Wartungsfenster-Automatik (Ankündigung → Save-All → Restart), Staging-Server mit Produktions-Seeds
- 🔜 H2 **Log-Store-Skalierung**: Continuous Aggregates für alle ACP-Charts, Compression-Tuning, Read-Replica für ACP-Queries (Gameplay-Isolation)
- 🔜 H3 **Chaos-Tests**: DB-Failover-Übung, Redis-Ausfall-Drill (Disk-Buffer ✅ beweist sich), Restore-Drill automatisiert monatlich

## P. Community, Team & Fairness

- ✅ Whitelist mit Regeltest, Tickets/Reports, Sanktions-Workflow mit Beweispflicht, Discord-Alerts
- 🔜 H1 **Einsteiger-Erlebnis**: Mentoren-Programm (erfahrene Spieler als „Paten" mit UCP-Matching), Neuling-Kennzeichnung (dezent, nur für Team sichtbar), Starter-Quests als RP-Anstöße („Melde dich beim Bürgeramt")
- 🔜 H1 **Regelwerk 2.0**: versioniert mit Changelog ✅-Anspruch einlösen (CMS), Fall-Beispiele je Regel, Quiz-Fragen ✅ daran koppeln
- 🔜 H2 **Charakter-Schutzräume**: „Szenen-Anmeldung" für schweres RP (Folter/CK-Nähe) mit Consent-Mechanik im UCP — Hardcore JA, aber mit Einverständnis-Kultur
- 🔜 H2 **Team-Tools**: Spectate-Modus (geloggt ✅-Regel), Ghost-Teleport, Report-an-Szene-Sprung (aus Report-Zeitstempel direkt ins Replay!), Schichtübergabe-Notizen
- 🔜 H2 **Community-Events-Pipeline**: Event-Kalender (UCP ✅-Anschluss), Bewerbungs-Slots für Spieler-Events (Konzerte, Märkte), Director-Unterstützung (Absperrungen, NPC-Publikum)
- 🔜 H3 **Saisons & Story-Arcs**: server-weite Erzählbögen pro Quartal (z. B. „Wahljahr", „Hafenkrieg") mit Director-Events, Zeitungs-Begleitung, Finale-Events — kuratiertes Weltgeschehen über dem Sandbox-Fundament
- 🔜 H3 **Creator-Support**: Streamer-Modus (Stream-sichere Musik-Flags, Overlay-API mit Live-Charakterdaten), Clip-Export aus Replays (Karten-Video als MP4)

## Q. Monetarisierung (strikt regelkonform)

- 🔜 H2 Kosmetik-only-Shop: Kleidungs-Pakete, Charakter-Slots (4./5.), Wunschkennzeichen-Priorität, UCP-Profil-Themes — **niemals** Geld/Items/Fahrzeuge/Queue-Skip mit Gameplay-Wirkung (Cfx.re-ToS ✅ + Community-Vertrauen)
- 🔜 H2 Unterstützer-Abo: Discord-Rolle, Name in Credits, früher Zugriff auf Kosmetik — transparent ausgewiesen, wohin das Geld fließt (Server-Kosten-Seite)

---

## Priorisierte Reihenfolge (Empfehlung)

**H1 — „Launch-Polish" (vor/kurz nach Livegang):**
Live-Boot → HUD 2.0 + Interact-System + Inventar 2.0 → Smartphone-NUI + Voice produktiv → MDT-Tablet + Spurensicherung + Cuff/Search → Gerichtsverhandlungen → Diminishing Returns + Fixkosten → Emotes/Walkstyles → Schlaf/Hygiene → Raub-Stufen 1–3 + Fahrzeug-Aufbruch → Charaktererstellung 2.0 → Nebula-Web-Refresh + Live-Statusseite → Einsteiger-Erlebnis.

**H2 — „Tiefe" (Monate 2–6):**
Physische Waren-Ökonomie + Worker-to-Owner → Haft/Bewährung/Pfändung + Haushalts-Politik → Crew-Tech-Tree + Straßen-Ruf + Qualitäts-Drogen → Feuerwehr + Director-Ausbau → Möbel + Miete + Lage-Score → Landwirtschaft/Jagd/Gastro → Darknet + Radio + Zeitung 2.0 → Geldfluss-Graph + Replay 2.0 + Fall-Verwaltung → Anti-Cheat 2.0 + Observability.

**H3 — „Weltklasse" (ab Monat 6):**
Erbe/Generationen + Chronik + Cinematics → Hafen-Import/Export + Gewerkschaften → Renn-/Sport-Ligen + Freizeit-Welt → Saisons & Story-Arcs → Kronzeugen/Zeugenschutz → Mobile-PWA + Creator-Support.

---

*Dieses Dokument ist der lebende Nordstern. Jeder umgesetzte Punkt wandert mit
✅ in die Status-Tabelle des README; jede neue Idee wird hier eingeordnet —
gegen die Design-Verfassung (§0) geprüft, bevor sie gebaut wird.*
