# hrp_skills

Skills verbessern sich **ausschließlich durch Nutzung** (Module rufen
`AddXp(charId, skill, amount, src)`), kein XP-Kauf. Level = `floor(sqrt(xp/100))`
(pure Formel in `shared/leveling.lua`, getestet). Täglicher **Decay** bei
Nichtnutzung (Rate/Karenz via Tuning), nie unter das halbe aktuelle Level.

Exports: `AddXp`, `GetLevel`. Befehl: `/skills`. Event: `skill.level_up`.
Tuning: `skills.decay_rate_per_day` (0.02) · `skills.decay_grace_days` (3).

DoD: 1 ✅ (Formel unit-getestet) 2 ✅ 3 ✅ 4 ✅ 5 ✅
