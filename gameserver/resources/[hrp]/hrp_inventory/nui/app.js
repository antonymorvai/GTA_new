/* Inventar 2.0 — Grid mit Drag&Drop, Dual-Panel, Kontextmenü.
   Reine Anzeige; jede Aktion läuft über die abgesicherten Server-Events. */

const inv = document.getElementById('inv');
const ctx = document.getElementById('ctx');
let state = null;
let ctxUuid = null;

const ICONS = {
    water_bottle: '💧', bread: '🍞', bandage: '🩹', phone: '📱',
    weapon_pistol: '🔫', ammo_9mm: '📦', fish: '🐟', iron_ore: '⛏',
    wood_log: '🪵', weed_raw: '🌿', weed_packed: '📦', cloth: '🧵',
    metal_parts: '⚙️', lockpick: '🔓', repair_kit: '🧰', toolbox: '🧰',
    radio: '📻', evidence_kit: '🔬',
};

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    });
}

function slotEl(item, side) {
    const el = document.createElement('div');
    el.className = 'slot';
    el.draggable = true;
    el.dataset.uuid = item.uuid;
    el.dataset.side = side;

    const emoji = ICONS[item.name] || '📦';
    const qty = item.quantity > 1 ? `<span class="qty">${item.quantity}</span>` : '';
    const quality = item.quality != null
        ? `<div class="bar"><i style="width:${item.quality}%;background:${item.quality > 50 ? '#4ade80' : '#f59e0b'}"></i></div>` : '';
    el.innerHTML = `<span class="emoji">${emoji}</span>
        <span class="name">${item.label}</span>${qty}${quality}`;
    el.title = `${item.label}${item.serial_number ? ' · SN ' + item.serial_number : ''}`
        + `${item.quality != null ? ' · Qualität ' + item.quality + '%' : ''}`;

    el.addEventListener('dragstart', (e) => {
        el.classList.add('dragging');
        e.dataTransfer.setData('text/plain', JSON.stringify({ uuid: item.uuid, from: side }));
    });
    el.addEventListener('dragend', () => el.classList.remove('dragging'));
    el.addEventListener('dblclick', () => { if (side === 'primary') post('use', { uuid: item.uuid }); });
    el.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        if (side !== 'primary') return;
        ctxUuid = item.uuid;
        ctx.style.left = e.clientX + 'px';
        ctx.style.top = e.clientY + 'px';
        ctx.classList.remove('hidden');
    });
    return el;
}

function renderGrid(gridId, items, side, minSlots) {
    const grid = document.getElementById(gridId);
    grid.innerHTML = '';
    for (const item of items) grid.appendChild(slotEl(item, side));
    // leere Slots auffüllen
    for (let i = items.length; i < minSlots; i++) {
        const empty = document.createElement('div');
        empty.className = 'slot';
        empty.style.cursor = 'default';
        grid.appendChild(empty);
    }
}

function setupDropZone(gridId, side) {
    const grid = document.getElementById(gridId);
    grid.addEventListener('dragover', (e) => { e.preventDefault(); grid.classList.add('dropping'); });
    grid.addEventListener('dragleave', () => grid.classList.remove('dropping'));
    grid.addEventListener('drop', (e) => {
        e.preventDefault();
        grid.classList.remove('dropping');
        try {
            const data = JSON.parse(e.dataTransfer.getData('text/plain'));
            if (data.from === side) return; // gleicher Container -> nichts
            post('move', { uuid: data.uuid, dest: side });
        } catch { /* ignore */ }
    });
}

function render() {
    const s = state;
    renderGrid('grid-primary', s.primary || [], 'primary', 20);

    const weightPct = Math.min(100, (s.weight / s.maxWeight) * 100);
    document.getElementById('weight-fill').style.width = weightPct + '%';
    document.getElementById('weight-fill').classList.toggle('heavy', weightPct > 85);
    document.getElementById('weight-text').textContent =
        `${(s.weight / 1000).toFixed(1)} / ${(s.maxWeight / 1000).toFixed(0)} kg`;

    const panelSec = document.getElementById('panel-secondary');
    if (s.secondary) {
        panelSec.classList.remove('hidden');
        document.getElementById('secondary-title').textContent = s.secondary.label;
        renderGrid('grid-secondary', s.secondary.items || [], 'secondary', 20);
    } else {
        panelSec.classList.add('hidden');
    }
}

// Kontextmenü-Aktionen
ctx.querySelectorAll('.ctx-item').forEach((el) =>
    el.addEventListener('click', () => {
        ctx.classList.add('hidden');
        if (!ctxUuid) return;
        const act = el.dataset.act;
        if (act === 'use') post('use', { uuid: ctxUuid });
        else if (act === 'drop') post('drop', { uuid: ctxUuid });
        else if (act === 'give') {
            const targetId = prompt('Spieler-ID (muss neben dir stehen):');
            if (targetId) post('give', { uuid: ctxUuid, targetId });
        }
    }));
document.addEventListener('click', () => ctx.classList.add('hidden'));
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'show') {
        state = msg.state;
        inv.classList.remove('hidden');
        render();
    } else if (msg.action === 'hide') {
        inv.classList.add('hidden');
        ctx.classList.add('hidden');
    }
});

setupDropZone('grid-primary', 'primary');
setupDropZone('grid-secondary', 'secondary');
