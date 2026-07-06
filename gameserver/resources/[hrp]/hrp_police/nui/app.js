/* MDT-Tablet — Personen-/Fahrzeug-/Waffen-Abfragen + Fahndungsliste.
   Reine Anzeige; jede Abfrage läuft server-seitig und wird geloggt. */

const mdt = document.getElementById('mdt');
const results = document.getElementById('mdt-results');
const input = document.getElementById('mdt-input');
const searchbar = document.getElementById('searchbar');
let activeTab = 'person';

const PLACEHOLDERS = {
    person: 'Vorname Nachname …', vehicle: 'Kennzeichen …',
    serial: 'Seriennummer …', wanted: '',
};

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    });
}

function esc(s) { const d = document.createElement('div'); d.textContent = s ?? ''; return d.innerHTML; }
function money(c) { return (Number(c) / 100).toLocaleString('de-DE', { minimumFractionDigits: 2 }) + ' $'; }

function setTab(tab) {
    activeTab = tab;
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === tab));
    searchbar.style.display = tab === 'wanted' ? 'none' : 'flex';
    input.placeholder = PLACEHOLDERS[tab];
    input.value = '';
    results.innerHTML = '<p class="empty">Bereit für Abfrage.</p>';
    if (tab === 'wanted') post('mdtQuery', { kind: 'wanted' });
}

function query() {
    if (activeTab === 'wanted') return post('mdtQuery', { kind: 'wanted' });
    const q = input.value.trim();
    if (q.length < 1) return;
    results.innerHTML = '<p class="empty">Suche läuft …</p>';
    post('mdtQuery', { kind: activeTab, query: q });
}

const RENDER = {
    person(data) {
        if (!data || data.length === 0) return '<p class="empty">Keine Person registriert.</p>';
        return data.map((p) => {
            const warrants = p.warrants.length
                ? p.warrants.map((w) => `<span class="badge warrant">FAHNDUNG: ${esc(w.reason)}</span>`).join('')
                : '<span class="badge clean">Keine offene Fahndung</span>';
            const fines = p.openFines > 0 ? `<span class="badge fine">Offene Bußgelder: ${money(p.openFines)}</span>` : '';
            const records = p.records.length
                ? p.records.map((r) => `<div class="rec-line">${esc(r.law_code)} — ${esc(r.title || '?')} · ${String(r.created_at).slice(0, 10)}</div>`).join('')
                : '<div class="rec-line" style="color:#6b7280">Keine Einträge im Strafregister.</div>';
            return `<div class="record">
                <h3>${esc(p.firstName)} ${esc(p.lastName)}</h3>
                <div class="meta">geb. ${esc(p.dob)} · ${p.gender === 'm' ? 'männlich' : p.gender === 'f' ? 'weiblich' : 'divers'}${p.phone ? ' · ☎ ' + esc(p.phone) : ''}</div>
                <div>${warrants} ${fines}</div>
                <div class="rec-section"><div class="label">Strafregister</div>${records}</div>
            </div>`;
        }).join('');
    },
    vehicle(data) {
        if (!data) return '<p class="empty">Kennzeichen nicht registriert.</p>';
        const status = data.status === 'totaled'
            ? '<span class="badge stolen">TOTALSCHADEN</span>' : '<span class="badge ok">Zugelassen</span>';
        return `<div class="record">
            <h3>${esc(data.plate)} · ${esc(data.model)}</h3>
            <div class="meta">Halter: ${esc(data.owner)} · ${data.mileage.toLocaleString('de-DE')} km</div>
            <div>${status} <span class="badge ok">Versicherung: ${esc(data.insurance)}</span></div>
        </div>`;
    },
    serial(data) {
        if (!data) return '<p class="empty">Seriennummer nicht registriert.</p>';
        return `<div class="record">
            <h3>${esc(data.label)} · SN ${esc(data.serial)}</h3>
            <div class="meta">Registriert: ${esc(data.registered)} · ${data.shotsFired} Schuss abgegeben</div>
            <div><span class="badge ok">${esc(data.location)}</span></div>
        </div>`;
    },
    wanted(data) {
        if (!data || data.length === 0) return '<p class="empty">Keine aktiven Fahndungen. 🎉</p>';
        return data.map((w) => `<div class="record">
            <h3>🚨 ${esc(w.first_name)} ${esc(w.last_name)}</h3>
            <div class="meta">Fahndung #${w.id} · seit ${String(w.created_at).slice(0, 10)}</div>
            <div class="rec-line">${esc(w.reason)}</div>
        </div>`).join('');
    },
};

document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => setTab(t.dataset.tab)));
document.getElementById('mdt-go').addEventListener('click', query);
document.getElementById('mdt-close').addEventListener('click', () => post('mdtClose'));
input.addEventListener('keydown', (e) => { if (e.key === 'Enter') query(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('mdtClose'); });

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'mdtShow') {
        mdt.classList.remove('hidden');
        document.getElementById('officer-info').textContent =
            `${msg.info.officer} · Rang ${msg.info.grade}`;
        setTab('person');
    } else if (msg.action === 'mdtHide') {
        mdt.classList.add('hidden');
    } else if (msg.action === 'mdtResult') {
        results.innerHTML = (RENDER[msg.kind] || (() => ''))(msg.data);
    }
});
