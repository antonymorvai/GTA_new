/* Smartphone-NUI — Homescreen + Apps. Reine Anzeige; alle Aktionen laufen
   über die abgesicherten Server-Events (Client-Callbacks). */

const phone = document.getElementById('phone');
const screen = document.getElementById('screen');
let data = null;
let currentApp = 'home';
let currentThread = null;

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    });
}

function money(cents) {
    return (Number(cents) / 100).toLocaleString('de-DE', { minimumFractionDigits: 2 }) + ' $';
}

function esc(s) {
    const div = document.createElement('div');
    div.textContent = s ?? '';
    return div.innerHTML;
}

function contactName(number) {
    const c = data?.contacts.find((c) => c.number === number);
    return c ? c.name : number;
}

// --- Threads aus flacher Nachrichtenliste bauen ---
function threads() {
    const map = new Map();
    for (const m of data.messages) {
        const partner = m.from_number === data.myNumber ? m.to_number : m.from_number;
        if (!map.has(partner)) map.set(partner, []);
        map.get(partner).push(m);
    }
    return map;
}

// --- Renderer je App ---
const APPS = {
    home() {
        const now = new Date();
        screen.innerHTML = `
            <div class="home-clock">${now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}</div>
            <div class="home-number">${esc(data.myNumber)}</div>
            <div class="app-grid">
                ${[['messages', '💬', 'Nachrichten'], ['contacts', '👥', 'Kontakte'],
                   ['twitter', '🐦', 'Twitter'], ['ads', '📢', 'Anzeigen'],
                   ['bank', '💳', 'Bank'], ['refreshApp', '🔄', 'Aktualisieren']]
                    .map(([id, icon, label]) =>
                        `<button class="app" data-app="${id}"><span class="icon">${icon}</span>${label}</button>`)
                    .join('')}
            </div>`;
        screen.querySelectorAll('.app').forEach((el) =>
            el.addEventListener('click', () => {
                if (el.dataset.app === 'refreshApp') { post('refresh'); return; }
                openApp(el.dataset.app);
            }));
    },

    messages() {
        const map = threads();
        let html = `<div class="app-header">💬 Nachrichten
            <button id="new-sms">+ Neu</button></div>`;
        if (map.size === 0) html += '<p class="empty">Keine Unterhaltungen.</p>';
        for (const [partner, msgs] of map) {
            html += `<div class="list-item" data-partner="${esc(partner)}">
                <div class="title">${esc(contactName(partner))}</div>
                <div class="sub">${esc(msgs[0].body.slice(0, 40))}</div></div>`;
        }
        screen.innerHTML = html;
        screen.querySelectorAll('.list-item').forEach((el) =>
            el.addEventListener('click', () => { currentThread = el.dataset.partner; openApp('thread'); }));
        document.getElementById('new-sms')?.addEventListener('click', () => {
            const number = prompt('Nummer (7-stellig):');
            if (number) { currentThread = number.trim(); openApp('thread'); }
        });
    },

    thread() {
        const msgs = (threads().get(currentThread) ?? []).slice().reverse();
        screen.innerHTML = `
            <div class="app-header"><button id="back">‹</button> ${esc(contactName(currentThread))}</div>
            <div id="bubbles">${msgs.map((m) => `
                <div class="bubble ${m.from_number === data.myNumber ? 'me' : 'them'}">
                    ${esc(m.body)}<span class="time">${new Date(m.sent_at).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}</span>
                </div>`).join('')}</div>
            <div class="composer"><input id="sms-input" placeholder="Nachricht …" maxlength="500">
            <button id="sms-send">➤</button></div>`;
        document.getElementById('back').addEventListener('click', () => openApp('messages'));
        const send = () => {
            const body = document.getElementById('sms-input').value.trim();
            if (body) post('sms', { number: currentThread, body });
        };
        document.getElementById('sms-send').addEventListener('click', send);
        document.getElementById('sms-input').addEventListener('keydown', (e) => e.key === 'Enter' && send());
        screen.scrollTop = screen.scrollHeight;
    },

    contacts() {
        screen.innerHTML = `<div class="app-header">👥 Kontakte</div>
            ${data.contacts.map((c) => `
                <div class="list-item" data-number="${esc(c.number)}">
                    <div class="title">${esc(c.name)}</div><div class="sub">${esc(c.number)}</div>
                </div>`).join('') || '<p class="empty">Keine Kontakte.</p>'}
            <div class="composer"><input id="c-name" placeholder="Name" maxlength="64">
            <input id="c-number" placeholder="Nummer" maxlength="7" style="max-width:90px">
            <button id="c-add">+</button></div>`;
        screen.querySelectorAll('.list-item').forEach((el) =>
            el.addEventListener('click', () => { currentThread = el.dataset.number; openApp('thread'); }));
        document.getElementById('c-add').addEventListener('click', () => {
            const name = document.getElementById('c-name').value.trim();
            const number = document.getElementById('c-number').value.trim();
            if (name && number) post('addContact', { name, number });
        });
    },

    twitter() {
        screen.innerHTML = `<div class="app-header">🐦 Twitter</div>
            <div class="composer mb"><textarea id="tw-input" rows="2" placeholder="Was gibt's Neues?" maxlength="280"></textarea>
            <button id="tw-send">➤</button></div>
            ${data.tweets.map((t) => `
                <div class="list-item"><div class="title">${esc(t.handle)}</div>
                <div class="sub">${esc(t.body)}</div></div>`).join('') || '<p class="empty">Noch keine Tweets.</p>'}`;
        document.getElementById('tw-send').addEventListener('click', () => {
            const body = document.getElementById('tw-input').value.trim();
            if (body) post('tweet', { body });
        });
    },

    ads() {
        screen.innerHTML = `<div class="app-header">📢 Kleinanzeigen</div>
            <div class="composer mb"><textarea id="ad-input" rows="2" placeholder="Anzeige aufgeben (kostenpflichtig) …" maxlength="300"></textarea>
            <button id="ad-send">➤</button></div>
            ${data.ads.map((a) => `
                <div class="list-item" data-number="${esc(a.phone_number)}">
                    <div class="title">${esc(a.body)}</div>
                    <div class="sub">Kontakt: ${esc(a.phone_number)} · antippen zum Schreiben</div>
                </div>`).join('') || '<p class="empty">Keine aktiven Anzeigen.</p>'}`;
        document.getElementById('ad-send').addEventListener('click', () => {
            const body = document.getElementById('ad-input').value.trim();
            if (body) post('ad', { body });
        });
        screen.querySelectorAll('.list-item').forEach((el) =>
            el.addEventListener('click', () => { currentThread = el.dataset.number; openApp('thread'); }));
    },

    bank() {
        screen.innerHTML = `<div class="app-header">💳 Bank</div>
            <div class="bank-card"><div class="label">Girokonto</div>
                <div class="amount">${money(data.bank)}</div></div>
            <div class="bank-card" style="background:linear-gradient(135deg,#374151,#111827)">
                <div class="label">Bargeld</div><div class="amount">${money(data.cash)}</div></div>
            <p class="empty">Überweisungen am Automaten oder in der Filiale.</p>`;
    },
};

function openApp(app) {
    currentApp = app;
    APPS[app]();
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'show') {
        phone.classList.remove('hidden');
        screen.innerHTML = '<p class="empty">Verbinde …</p>';
    } else if (msg.action === 'hide') {
        phone.classList.add('hidden');
        currentApp = 'home';
    } else if (msg.action === 'data') {
        data = msg.data;
        document.getElementById('pb-number').textContent = data.myNumber ?? '···';
        openApp(currentApp);
    }
});

document.getElementById('nav-home').addEventListener('click', () => openApp('home'));
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });
