/* Interact-NUI — Prompt, Kontextmenü (Tastatur-navigierbar), Betrags-Dialog. */

const promptEl = document.getElementById('prompt');
const menuEl = document.getElementById('menu');
const amountEl = document.getElementById('amount');
let selected = 0;
let optionCount = 0;

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    });
}

function renderMenu(title, options) {
    document.getElementById('menu-title').textContent = title;
    const box = document.getElementById('menu-options');
    optionCount = options.length;
    selected = 0;
    box.innerHTML = options.map((label, i) =>
        `<div class="menu-opt ${i === 0 ? 'active' : ''}" data-index="${i + 1}">${label}</div>`).join('');
    box.querySelectorAll('.menu-opt').forEach((el) => {
        el.addEventListener('click', () => post('select', { index: el.dataset.index }));
        el.addEventListener('mouseenter', () => { selected = Number(el.dataset.index) - 1; highlight(); });
    });
}

function highlight() {
    document.querySelectorAll('.menu-opt').forEach((el, i) =>
        el.classList.toggle('active', i === selected));
}

window.addEventListener('message', (event) => {
    const d = event.data;
    if (d.action === 'prompt') {
        document.getElementById('prompt-label').textContent = d.label;
        promptEl.classList.remove('hidden');
    } else if (d.action === 'clear') {
        promptEl.classList.add('hidden');
        menuEl.classList.add('hidden');
        amountEl.classList.add('hidden');
    } else if (d.action === 'menu') {
        promptEl.classList.add('hidden');
        renderMenu(d.label, d.options);
        menuEl.classList.remove('hidden');
    } else if (d.action === 'amount') {
        document.getElementById('amount-title').textContent =
            d.kind === 'deposit' ? 'Einzahlen ($)' : 'Abheben ($)';
        amountEl.dataset.kind = d.kind;
        amountEl.classList.remove('hidden');
        setTimeout(() => document.getElementById('amount-input').focus(), 30);
    }
});

document.addEventListener('keydown', (e) => {
    if (!menuEl.classList.contains('hidden')) {
        if (e.key === 'ArrowDown') { selected = (selected + 1) % optionCount; highlight(); e.preventDefault(); }
        else if (e.key === 'ArrowUp') { selected = (selected - 1 + optionCount) % optionCount; highlight(); e.preventDefault(); }
        else if (e.key === 'Enter') post('select', { index: selected + 1 });
        else if (e.key === 'Escape') post('cancel');
    } else if (!amountEl.classList.contains('hidden') && e.key === 'Escape') {
        amountEl.classList.add('hidden');
        post('amount', { kind: amountEl.dataset.kind, amount: 0 });
    }
});

document.getElementById('amount-ok').addEventListener('click', () => {
    amountEl.classList.add('hidden');
    post('amount', { kind: amountEl.dataset.kind, amount: document.getElementById('amount-input').value });
});
document.getElementById('amount-cancel').addEventListener('click', () => {
    amountEl.classList.add('hidden');
    post('amount', { kind: amountEl.dataset.kind, amount: 0 });
});
