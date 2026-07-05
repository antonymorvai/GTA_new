/* HUD-Renderer — empfängt Werte, zeigt Balken. Keine Logik, kein State. */

function setBar(id, value) {
    const el = document.getElementById('bar-' + id);
    const pct = Math.max(0, Math.min(100, value ?? 0));
    el.style.width = pct + '%';
    el.classList.toggle('low', pct <= 20);
}

window.addEventListener('message', (event) => {
    const d = event.data;
    if (d.action !== 'update') return;

    setBar('health', d.health);
    setBar('armor', d.armor);
    setBar('hunger', d.hunger);
    setBar('thirst', d.thirst);

    document.getElementById('row-armor').classList.toggle('hidden', !d.armor);
    document.getElementById('row-fuel').classList.toggle('hidden', d.fuel == null);
    if (d.fuel != null) setBar('fuel', d.fuel);

    if (d.clock) document.getElementById('clock').textContent = d.clock;

    const speedEl = document.getElementById('speed');
    speedEl.classList.toggle('hidden', d.speed == null);
    if (d.speed != null) speedEl.innerHTML = `${d.speed} <small>km/h</small>`;
});
