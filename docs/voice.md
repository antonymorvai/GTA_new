# Voice-Integration (SaltyChat)

3D-Voice mit Distanz, Funk und Telefonklang wird über **SaltyChat**
(TeamSpeak-basiert) integriert. SaltyChat wird aus Lizenzgründen **nicht in
diesem Repository** mitgeliefert — die Ressource muss vom Betreiber bezogen
werden (https://gaming.v10networks.com/saltychat).

## Installations-Schritte

1. TeamSpeak-3-Server aufsetzen (eigener Container oder extern) und das
   SaltyChat-TS-Plugin-Setup gemäß SaltyChat-Doku durchführen.
2. Ressource `saltychat` nach `gameserver/resources/` legen.
3. In `gameserver/server.cfg` ergänzen (vor den [hrp]-Ressourcen):
   ```
   ensure saltychat
   setr VoiceEnabled "true"
   setr ServerUniqueIdentifier "<TS-Server-UID>"
   setr MinimumPluginVersion ""
   setr SoundPack "default"
   setr IngameChannelId "<Channel-ID>"
   setr IngameChannelPassword "<Passwort>"
   ```
4. Distanz-Stufen (Flüstern/Normal/Schreien) und Funk konfiguriert SaltyChat
   selbst; die HardcoreRP-Anbindung (Funkfrequenzen als Items, Störsender,
   Telefon-Voice-Routing über `hrp_phone`) folgt in Phase 3 als eigene
   Brücken-Ressource `hrp_voice`.

## Geplantes Logging (Katalog-Namespace reserviert)

| Event | Inhalt |
|---|---|
| `comms.call_meta` | Anruf-Metadaten: Nummern, Start/Ende, Dauer — IMMER |
| `comms.call_content` | Nur bei aktivem richterlichem In-RP-Beschluss (Abhör-Workflow, Phase 3 Justiz) |
| `comms.radio` | Funk-Metadaten (Frequenz, Sender, Dauer) |

Bis zur Voice-Integration deckt `hrp_phone` SMS vollständig ab (`comms.sms`).
