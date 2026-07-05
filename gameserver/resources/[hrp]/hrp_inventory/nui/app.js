/* Inventar-NUI — Anzeige + Aktions-Anfragen; jede Aktion validiert der Server. */

const panel = document.getElementById('inventory');
const itemsEl = document.getElementById('items');
const weightEl = document.getElementById('weight');
const weightFill = document.getElementById('weight-fill');

function post(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    });
}

document.getElementById('btn-close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });

function render(items, weight, maxWeight) {
    weightEl.textContent = `${(weight / 1000).toFixed(1)} / ${(maxWeight / 1000).toFixed(0)} kg`;
    const pct = Math.min(100, (weight / maxWeight) * 100);
    weightFill.style.width = pct + '%';
    weightFill.classList.toggle('heavy', pct > 85);

    itemsEl.innerHTML = '';
    if (!items || items.length === 0) {
        itemsEl.innerHTML = '<p class="empty">Deine Taschen sind leer.</p>';
        return;
    }

    for (const item of items) {
        const el = document.createElement('div');
        el.className = 'item';

        const name = document.createElement('div');
        name.className = 'name';
        name.textContent = `${item.label}${item.quantity > 1 ? ` ×${item.quantity}` : ''}`;

        const meta = document.createElement('div');
        meta.className = 'meta';
        const parts = [`${((item.weight_grams * item.quantity) / 1000).toFixed(1)} kg`];
        if (item.quality != null) parts.push(`Qualität ${item.quality}%`);
        if (item.serial_number) parts.push(`SN ${item.serial_number}`);
        meta.textContent = parts.join(' · ');

        const actions = document.createElement('div');
        actions.className = 'actions';

        const useBtn = document.createElement('button');
        useBtn.className = 'primary';
        useBtn.textContent = 'Benutzen';
        useBtn.addEventListener('click', () => post('use', { uuid: item.uuid }));

        const giveBtn = document.createElement('button');
        giveBtn.textContent = 'Geben';
        giveBtn.addEventListener('click', () => {
            const targetId = prompt('Spieler-ID (muss neben dir stehen):');
            if (targetId) post('give', { uuid: item.uuid, targetId });
        });

        const dropBtn = document.createElement('button');
        dropBtn.textContent = 'Ablegen';
        dropBtn.addEventListener('click', () => post('drop', { uuid: item.uuid }));

        actions.append(useBtn, giveBtn, dropBtn);
        el.append(name, meta, actions);
        itemsEl.appendChild(el);
    }
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'show') {
        panel.classList.remove('hidden');
        render(msg.items, msg.weight, msg.maxWeight);
    } else if (msg.action === 'hide') {
        panel.classList.add('hidden');
    }
});
