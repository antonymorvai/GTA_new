/**
 * Regeltest-Fragen. Die korrekten Antworten bleiben server-seitig —
 * der Client erhält nur Fragen + Optionen. Bestehen: >= PASS_SCORE richtig.
 */
export const PASS_SCORE = 8;

export interface RuleQuestion {
  id: string;
  question: string;
  options: string[];
  correct: number; // Index — wird NIE an den Client gesendet
}

export const RULE_QUESTIONS: RuleQuestion[] = [
  {
    id: 'meta',
    question: 'Du erfährst im Discord, wo ein Spieler sein Fahrzeug versteckt hat. Was darfst du damit in-game anfangen?',
    options: [
      'Ich fahre hin und stehle es',
      'Nichts — Informationen von außerhalb des Spiels sind Metagaming',
      'Ich darf es nutzen, wenn ich es „zufällig" finde',
      'Ich melde es der Polizei in-game',
    ],
    correct: 1,
  },
  {
    id: 'nlr',
    question: 'Dein Charakter wurde bewusstlos geschossen und in der Klinik behandelt. Was gilt für deine Erinnerung?',
    options: [
      'Ich erinnere mich an alles und räche mich sofort',
      'Ich erinnere mich grob, darf aber keine Rache nehmen',
      'Mein Charakter erinnert sich nicht an die unmittelbare Situation des Downs (New-Life-ähnliche Regel)',
      'Ich darf die Täter im Report nennen und in-game jagen',
    ],
    correct: 2,
  },
  {
    id: 'rdm',
    question: 'Was ist RDM?',
    options: [
      'Das Ausrauben eines Spielers ohne Wertgegenstände',
      'Das Töten/Angreifen ohne RP-Grund und Interaktion',
      'Das Fahren ohne Führerschein',
      'Ein erlaubter Gang-Überfall',
    ],
    correct: 1,
  },
  {
    id: 'value',
    question: 'Wann darfst du dein eigenes Leben in Gefahr bringen (Fear-RP)?',
    options: [
      'Immer, es ist nur ein Spiel',
      'Wenn ich mehr Waffen habe als der Angreifer',
      'Mein Charakter hängt an seinem Leben und handelt entsprechend — Heldentum gegen gezogene Waffen ist Powergaming',
      'Wenn meine Gang in der Nähe ist',
    ],
    correct: 2,
  },
  {
    id: 'power',
    question: 'Was ist Powergaming?',
    options: [
      'Anderen durch RP keine Reaktionsmöglichkeit lassen / Unmögliches ausspielen',
      'Besonders gutes, dominantes RP',
      'Das Nutzen von Skills',
      'Doppel-Jobs annehmen',
    ],
    correct: 0,
  },
  {
    id: 'ck',
    question: 'Wann stirbt dein Charakter endgültig (CK)?',
    options: [
      'Bei jedem Down',
      'Nach 3 Downs am selben Tag',
      'Nur per genehmigtem CK-Antrag oder in dokumentierten Ausnahmesituationen',
      'Wenn die Polizei dich erschießt',
    ],
    correct: 2,
  },
  {
    id: 'combatlog',
    question: 'Du wirst gerade ausgeraubt und dein Internet „fällt aus". Wie wird das gewertet?',
    options: [
      'Pech für die Räuber',
      'Als Combat-Logging — nachweisbar über die Server-Logs und sanktionierbar',
      'Als technischer Fehler ohne Folgen',
      'Ich muss nur den Support informieren',
    ],
    correct: 1,
  },
  {
    id: 'scam',
    question: 'Darfst du andere Spieler in-game betrügen (Scamming)?',
    options: [
      'Nein, niemals',
      'Ja, unbegrenzt',
      'In engen Grenzen mit RP-Substanz — Echtgeld-/OOC-Betrug ist immer verboten',
      'Nur als Gang-Mitglied',
    ],
    correct: 2,
  },
  {
    id: 'report',
    question: 'Ein Spieler bricht massiv Regeln. Was ist der richtige Weg?',
    options: [
      'Ich beleidige ihn im OOC-Chat',
      'Ich breche selbst Regeln, um es auszugleichen',
      'Ich spiele die Situation zu Ende und erstelle danach einen Report mit Beweisen im UCP',
      'Ich verlasse sofort den Server',
    ],
    correct: 2,
  },
  {
    id: 'ooc',
    question: 'Was gehört NICHT in den IC-Funk/Chat?',
    options: [
      'Straßennamen',
      'OOC-Begriffe wie „Regelwerk", „Support", „Client-Absturz"',
      'Funksprüche der Fraktion',
      'Preisverhandlungen',
    ],
    correct: 1,
  },
];
