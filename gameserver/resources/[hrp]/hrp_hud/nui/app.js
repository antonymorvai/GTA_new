/* HUD 2.0 Renderer — Ringe (SVG-Dashoffset), Statuseffekt-Chips, Fahrzeug-Panel.
   Reine Anzeige, kein State außer der letzten Werte für sanfte Übergänge. */

const CIRC = 2 * Math.PI * 19; // Umfang r=19

function setRing(id, value, { hideWhenFull = false } = {}) {
    const ring = document.getElementById('ring-' + id);
    const fg = ring.querySelector('circle.fg');
    const pct = Math.max(0, Math.min(100, value ?? 0));
    fg.style.strokeDashoffset = CIRC * (1 - pct / 100);
    ring.classList.toggle('low', pct <= 20);
    // "ruhig" = voll & unkritisch -> dezent ausblenden (Vollbild-Immersion)
    ring.classList.toggle('calm', hideWhenFull && pct >= 95);
}

const STATUS_META = {
    bleeding:   { label: 'Blutung',     cls: 'danger', icon: '🩸' },
    injured:    { label: 'Verletzt',    cls: 'danger', icon: '🤕' },
    overweight: { label: 'Überladen',   cls: 'warn',   icon: '🎒' },
    stress:     { label: 'Stress',      cls: 'warn',   icon: '🧠' },
    high:       { label: 'Berauscht',   cls: 'info',   icon: '💊' },
    talking:    { label: 'Spricht',     cls: 'info',   icon: '🎙' },
};

function renderStatus(list) {
    const container = document.getElementById('status-icons');
    const wanted = (list || []).filter((s) => STATUS_META[s]);
    container.innerHTML = wanted.map((s) => {
        const m = STATUS_META[s];
        return `<div class="status-chip ${m.cls}"><span class="dot"></span>${m.icon} ${m.label}</div>`;
    }).join('');
}

window.addEventListener('message', (event) => {
    const d = event.data;
    if (d.action !== 'update') return;

    setRing('health', d.health);
    setRing('armor', d.armor, { hideWhenFull: true });
    setRing('hunger', d.hunger, { hideWhenFull: true });
    setRing('thirst', d.thirst, { hideWhenFull: true });
    // Stress: invertiert (0 = ruhig -> ausblenden, hoch = auffällig)
    setRing('stress', d.stress ?? 0, {});
    document.getElementById('ring-stress').classList.toggle('calm', (d.stress ?? 0) < 20);

    // Rüstung nur zeigen, wenn vorhanden
    document.getElementById('ring-armor').classList.toggle('hidden', !d.armor);

    if (d.clock) document.getElementById('clock').textContent = d.clock;

    // Mikrofon-Indikator
    document.getElementById('ring-voice').classList.toggle('active', !!d.voice);

    // Fahrzeug-Panel
    const veh = document.getElementById('vehicle');
    if (d.speed != null) {
        veh.classList.remove('hidden');
        document.getElementById('speed').innerHTML = `${d.speed}<small>km/h</small>`;
        if (d.fuel != null) setRing('fuel', d.fuel);
        document.getElementById('ring-fuel').classList.toggle('hidden', d.fuel == null);
    } else {
        veh.classList.add('hidden');
    }

    renderStatus(d.status);
});
