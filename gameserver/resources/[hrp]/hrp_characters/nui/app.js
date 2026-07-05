/* Charakterauswahl-NUI — reine Anzeige, alle Entscheidungen trifft der Server. */

const app = document.getElementById('app');
const listEl = document.getElementById('character-list');
const createForm = document.getElementById('create-form');
const formError = document.getElementById('form-error');
const backstoryEl = document.getElementById('backstory');
const backstoryCount = document.getElementById('backstory-count');

let maxSlots = 3;

function post(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    });
}

function renderList(characters) {
    listEl.innerHTML = '';
    for (const c of characters) {
        const card = document.createElement('div');
        card.className = 'char-card';
        const cash = ((c.cash ?? 0) / 100).toLocaleString('de-DE', { style: 'currency', currency: 'USD' });
        card.innerHTML = `
            <div class="name"></div>
            <div class="meta">Slot ${c.slot} · geb. ${c.date_of_birth?.slice?.(0, 10) ?? c.date_of_birth} · ${Math.floor(c.played_minutes / 60)} h Spielzeit · ${cash}</div>
            <div class="actions">
                <button class="btn primary select">Spielen</button>
                <button class="btn danger">Löschen</button>
            </div>`;
        card.querySelector('.name').textContent = `${c.first_name} ${c.last_name}`;
        card.querySelector('.select').addEventListener('click', () => post('selectCharacter', { characterId: c.id }));
        card.querySelector('.danger').addEventListener('click', () => {
            if (confirm(`${c.first_name} ${c.last_name} wirklich löschen?`)) {
                post('deleteCharacter', { characterId: c.id });
            }
        });
        listEl.appendChild(card);
    }
    for (let i = characters.length; i < maxSlots; i++) {
        const empty = document.createElement('div');
        empty.className = 'empty-slot';
        empty.textContent = 'Freier Slot';
        listEl.appendChild(empty);
    }
    document.getElementById('btn-new').style.display = characters.length >= maxSlots ? 'none' : 'block';
}

backstoryEl.addEventListener('input', () => {
    backstoryCount.textContent = `${backstoryEl.value.length} / 200`;
});

document.getElementById('btn-new').addEventListener('click', () => {
    formError.classList.add('hidden');
    createForm.classList.remove('hidden');
});

document.getElementById('btn-cancel').addEventListener('click', () => {
    createForm.classList.add('hidden');
});

document.getElementById('btn-create').addEventListener('click', () => {
    formError.classList.add('hidden');
    post('createCharacter', {
        firstName: document.getElementById('firstName').value.trim(),
        lastName: document.getElementById('lastName').value.trim(),
        dateOfBirth: document.getElementById('dateOfBirth').value,
        gender: document.getElementById('gender').value,
        backstory: backstoryEl.value.trim(),
    });
});

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'list') {
        maxSlots = msg.maxSlots || 3;
        app.classList.remove('hidden');
        renderList(msg.characters || []);
    } else if (msg.action === 'createResult') {
        if (msg.ok) {
            createForm.classList.add('hidden');
        } else {
            formError.textContent = msg.message || 'Erstellung fehlgeschlagen.';
            formError.classList.remove('hidden');
        }
    } else if (msg.action === 'hide') {
        app.classList.add('hidden');
        createForm.classList.add('hidden');
    }
});
