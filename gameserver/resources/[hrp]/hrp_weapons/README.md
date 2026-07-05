# hrp_weapons

Waffen sind **Item-Instanzen mit Seriennummer** — sie entstehen nie aus dem
Nichts: Ausrüsten/Wegstecken über das Inventar („Benutzen" auf der Waffe),
geladene Munition lebt in den Instanz-Metadaten (`ammo_loaded`),
Munitions-Items laden die ausgerüstete Waffe (Verbrauch + `weapon.load`).

**Schusszähler:** Der Client meldet Schüsse gebatcht (5 s); der Server klemmt
auf die geladene Munition (Manipulation kann nie Munition erzeugen), erhöht
`shots_fired` der Instanz und loggt `combat.shot` mit Seriennummer — die
Ballistik-Datenbasis für `/serialcheck` und Ermittlungen.

**Besitz = Trageberechtigung:** Wird die Instanz abgelegt/übergeben/als Beweis
eingelagert, entzieht der `instanceMoved`-Hook die Waffe sofort.

Neue Waffen: Eintrag in der `WEAPONS`-Registry + Item-Definition (`is_unique=1`,
`usable=1`, category `weapon`).

DoD: 1 ✅ 2 ✅ (equip/holster/load/shot + item.modify) 3 ✅ (Magazin/Ladung je
Waffe in der Registry) 4 ✅ (`/serialcheck`, Item-Trace) 5 ✅
