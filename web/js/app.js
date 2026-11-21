// Lemaire TV, version web pour iPhone (Safari, ajoutée à l'écran d'accueil).

import * as api from './api.js';
import { profiles, myList, lists, progress } from './store.js';
import { parseTitle, cleanTitle, groupVersions, qualityRank } from './titles.js';

const $ = (sel, el = document) => el.querySelector(sel);
const app = $('#app');

// ---------- Petits utilitaires ----------

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const ICONS = {
  home: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
  movie: 'M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L5 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z',
  series: 'M4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6zm16-4H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-8 12.5v-9l6 4.5-6 4.5z',
  tv: 'M21 6h-7.59l3.29-3.29L16 2l-4 4-4-4-.71.71L10.59 6H3c-1.1 0-2 .89-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.11-.9-2-2-2zm0 14H3V8h18v12zM9 10v8l7-4z',
  bookmark: 'M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2z',
  search: 'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0016 9.5 6.5 6.5 0 109.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
  play: 'M8 5v14l11-7z',
  add: 'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z',
  check: 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
  info: 'M11 7h2v2h-2zm0 4h2v6h-2zm1-9C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z',
  back: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z',
  chev: 'M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z',
  star: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
  close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
  more: 'M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
  list: 'M3 10h11v2H3zm0-4h11v2H3zm0 8h7v2H3zm13-1v8l6-4z',
  circle: 'M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z',
  checkCircle: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z',
  vlc: 'M12 2L5 20h14L12 2zm0 4.5l1.6 4.5h-3.2L12 6.5zM9.7 13h4.6l1.1 3H8.6l1.1-3z',
  trash: 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z',
  edit: 'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 000-1.41l-2.34-2.34a1 1 0 00-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z',
  swap: 'M16 17.01V10h-2v7.01h-3L15 21l4-3.99h-3zM9 3L5 6.99h3V14h2V6.99h3L9 3z',
  sad: 'M15.5 9.5m-1.5 0a1.5 1.5 0 103 0 1.5 1.5 0 10-3 0M8.5 9.5m-1.5 0a1.5 1.5 0 103 0 1.5 1.5 0 10-3 0M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm0-6c-2.33 0-4.32 1.45-5.12 3.5h1.67c.69-1.19 1.97-2 3.45-2s2.75.81 3.45 2h1.67c-.8-2.05-2.79-3.5-5.12-3.5z',
};
const icon = (name, cls = '') =>
  `<svg class="${cls}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="${ICONS[name]}"/></svg>`;

const AVATAR = ['#ff2e7e', '#7b2ff7', '#00a6d6', '#f77f00', '#2ec4b6', '#e63946'];
function colorFor(id) {
  let h = 0x811c9dc5;
  for (const c of String(id)) h = Math.imul(h ^ c.charCodeAt(0), 0x01000193) >>> 0;
  return AVATAR[(h & 0x7fffffff) % AVATAR.length];
}
const initial = (name) => (String(name).trim()[0] || '?').toUpperCase();

function toast(text) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = text;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2200);
}

const go = (hash) => {
  if (location.hash === hash) render();
  else location.hash = hash;
};

// Mémoire des éléments affichés, pour ouvrir une fiche sans recharger.
const known = new Map();
const remember = (item) => {
  known.set(`${item.type}:${item.id}`, item);
  return item;
};

function minutes(sec) {
  const s = Math.max(0, Math.round(sec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return h ? `${h} h ${String(m).padStart(2, '0')}` : `${m} min`;
}

// ---------- Vignettes et rangées ----------

function card(item, { wide = false, sub = '', pct = null } = {}) {
  remember(item);
  const title = cleanTitle(item.name);
  const live = item.type === 'live';
  const cls = live ? 'card channel' : wide ? 'card wide' : 'card';
  const src = api.img(item.img);
  return `<button class="${cls}" data-open="${item.type}:${esc(item.id)}">
    <div class="art">
      ${src ? `<img loading="lazy" src="${esc(src)}" alt="" onerror="this.remove()">` : ''}
      ${!src || !live ? `<div class="fallback" style="${src ? 'z-index:-1' : ''}">${esc(title)}</div>` : ''}
      ${wide ? `<div class="play"><span>${icon('play')}</span></div>` : ''}
      ${pct != null ? `<div class="bar"><i style="width:${Math.round(pct * 100)}%"></i></div>` : ''}
    </div>
    <div class="label">${esc(title)}</div>
    ${sub ? `<div class="sub">${esc(sub)}</div>` : ''}
  </button>`;
}

function row(title, items, opts = {}) {
  if (!items.length) return '';
  const head = opts.seeAll
    ? `<a class="row-head" href="${opts.seeAll}">${esc(title)}${icon('chev', 'chev')}</a>`
    : `<div class="row-head">${esc(title)}${opts.menu ? `<button class="more" data-list-menu="${opts.menu}">${icon('more')}</button>` : ''}</div>`;
  return `<section class="row">${head}<div class="strip">${items.map((i) => card(i, opts.card ? opts.card(i) : {})).join('')}</div></section>`;
}

/** Rangée de catégorie chargée quand elle approche de l'écran. */
function lazyRow(kind, cat) {
  return `<section class="row lazy" data-kind="${kind}" data-cat="${esc(cat.id)}" data-name="${esc(cat.name)}">
    <a class="row-head" href="#/cat/${kind}/${encodeURIComponent(cat.id)}">${esc(cleanTitle(cat.name))}${icon('chev', 'chev')}</a>
    <div class="strip" style="min-height:calc(var(--poster) * 1.5 + 24px)"></div>
  </section>`;
}

let observer;
function watchLazyRows() {
  observer?.disconnect();
  observer = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        observer.unobserve(e.target);
        fillRow(e.target);
      }
    },
    { rootMargin: '400px 0px' },
  );
  document.querySelectorAll('.row.lazy').forEach((el) => observer.observe(el));
}

async function fillRow(el) {
  const { kind, cat } = el.dataset;
  try {
    const items = await api.streams(kind, cat);
    const shown = (kind === 'live' ? items : groupVersions(items)).slice(0, 40);
    if (!shown.length) return el.remove();
    $('.strip', el).style.minHeight = '';
    $('.strip', el).innerHTML = shown.map((i) => card(i)).join('');
  } catch {
    el.remove();
  }
}

// ---------- Coquille : barre du haut + onglets ----------

const TABS = [
  ['#/accueil', 'Accueil', 'home'],
  ['#/films', 'Films', 'movie'],
  ['#/series', 'Séries', 'series'],
  ['#/tv', 'TV', 'tv'],
  ['#/liste', 'Ma liste', 'bookmark'],
];

function shell(active, content, { title = null, overlay = false } = {}) {
  const p = profiles.current;
  const brand = `<div class="brand"><span class="logo">${icon('play')}</span>Lemaire<b>TV</b></div>`;
  return `
    <header class="topbar ${overlay ? 'overlay' : ''}">
      ${title ? `<h1>${esc(title)}</h1>` : brand}
      <span class="spacer"></span>
      <a class="icon-btn" href="#/recherche" aria-label="Rechercher">${icon('search')}</a>
      <button class="avatar" style="background:${colorFor(p.id)}" data-profile-menu>${esc(initial(p.name))}</button>
    </header>
    <main>${content}</main>
    <nav class="tabs">${TABS.map(([h, l, i]) => `<a href="${h}" class="${h === active ? 'on' : ''}"><span class="pill">${icon(i)}</span>${l}</a>`).join('')}</nav>`;
}

const loading = '<div class="loading"><div class="spinner"></div></div>';

function installHint() {
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const standalone = navigator.standalone || matchMedia('(display-mode: standalone)').matches;
  if (!ios || standalone || localStorage.getItem('ltv.hideInstall')) return '';
  return `<div class="install" data-hide-install>
    <b>Installe Lemaire TV sur ton écran d'accueil</b>
    Dans Safari, touche le bouton Partager (le carré avec une flèche), puis « Sur l'écran d'accueil ». L'app s'ouvrira alors en plein écran, comme une vraie app.
  </div>`;
}

// ---------- Écrans ----------

function viewProfiles(editing = false) {
  const all = profiles.all();
  if (!all.length) return viewAddProfile(true);
  app.innerHTML = `<div class="center">
    <div style="display:flex;align-items:center"><div class="brand"><span class="logo">${icon('play')}</span>Lemaire<b>TV</b></div>
    <span class="spacer" style="flex:1"></span><button class="link" data-edit-profiles>${editing ? 'Terminé' : 'Modifier'}</button></div>
    <div class="body">
      <h2>${editing ? 'Gérer les profils' : 'Qui regarde ?'}</h2>
      <p></p>
      <div class="profiles">
        ${all.map((p) => `<button class="profile" data-profile="${esc(p.id)}" data-editing="${editing ? 1 : ''}">
          <div class="sq" style="background:linear-gradient(135deg, ${colorFor(p.id)}, #000a)">${esc(initial(p.name))}
            ${editing ? `<div class="del">${icon('trash')}</div>` : ''}</div>
          <div class="name">${esc(p.name)}</div></button>`).join('')}
        ${editing ? '' : `<a class="profile" href="#/ajouter"><div class="sq add">${icon('add')}</div><div class="name">Ajouter</div></a>`}
      </div>
    </div></div>`;
}

function viewAddProfile(first = false) {
  app.innerHTML = `${first ? '' : `<a class="back" href="#/profils">${icon('back')}</a>`}
  <form class="form" id="add-form" autocomplete="off">
    <h2>${first ? 'Bienvenue !' : 'Nouveau profil'}</h2>
    <p class="intro">Entre les codes envoyés par ton fournisseur IPTV (dans le mail d'abonnement, rubrique « Codes Xtream »).</p>
    <p class="error hidden" id="add-error"></p>
    <div class="field"><label>Prénom</label><input name="name" placeholder="Ex. Léo, Maman…" required></div>
    <div class="field"><label>Adresse du serveur</label><input name="server" inputmode="url" autocapitalize="off" placeholder="http://monserveur.net" required>
      <small>Astuce : tu peux aussi coller ici ton lien M3U, les codes seront remplis tout seuls.</small></div>
    <div class="field"><label>Identifiant</label><input name="user" autocapitalize="off" autocorrect="off" required></div>
    <div class="field"><label>Mot de passe</label><input name="pass" type="password" autocapitalize="off" required></div>
    <button class="btn block" type="submit">Se connecter</button>
    <p class="privacy">Tes codes restent sur ce téléphone et ne sont envoyés qu'à ton fournisseur.</p>
  </form>`;
  const f = $('#add-form');
  f.server.addEventListener('input', () => {
    const codes = api.fromM3uLink(f.server.value);
    if (codes) {
      f.server.value = codes.server;
      f.user.value = codes.user;
      f.pass.value = codes.pass;
    }
  });
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const err = $('#add-error');
    const btn = f.querySelector('button[type=submit]');
    const server = api.normalizeServer(f.server.value);
    if (!server) {
      err.textContent = 'Adresse du serveur invalide.';
      err.classList.remove('hidden');
      return;
    }
    btn.disabled = true;
    btn.textContent = 'Connexion…';
    try {
      const data = await api.login(server, f.user.value.trim(), f.pass.value);
      const p = {
        id: Date.now().toString(36),
        name: f.name.value.trim(),
        server,
        user: f.user.value.trim(),
        pass: f.pass.value,
        maxConn: Number(data.user_info.max_connections) || 0,
      };
      profiles.add(p);
      profiles.current = p;
      go('#/accueil');
      if (p.maxConn === 1) {
        setTimeout(() => toast('Ton abonnement ne permet qu’un seul appareil à la fois.'), 600);
      }
    } catch (ex) {
      err.textContent =
        ex.message === 'codes'
          ? 'Identifiant ou mot de passe refusé par le serveur.'
          : 'Impossible de joindre le serveur. Vérifie l’adresse.';
      err.classList.remove('hidden');
      btn.disabled = false;
      btn.textContent = 'Se connecter';
    }
  });
}

function continueItems() {
  return progress
    .all()
    .filter((p) => p.dur > 0 && p.pos / p.dur > 0.02 && p.pos / p.dur < 0.95)
    .slice(0, 15);
}

function continueRow() {
  const items = continueItems();
  return row('Continuer à regarder', items, {
    card: (p) => ({
      wide: true,
      pct: p.pos / p.dur,
      sub: `Reste ${minutes(p.dur - p.pos)}`,
    }),
  });
}

async function viewHome() {
  app.innerHTML = shell('#/accueil', loading, { overlay: true });
  let vodCats = [];
  let seriesCats = [];
  try {
    [vodCats, seriesCats] = await Promise.all([api.categories('vod'), api.categories('series')]);
  } catch {
    app.innerHTML = shell('#/accueil', errorBox());
    return;
  }
  // Affiche à la une : un film bien noté de la première catégorie, change chaque jour.
  let hero = null;
  if (vodCats[0]) {
    try {
      const first = groupVersions(await api.streams('vod', vodCats[0].id)).filter((i) => i.img);
      const pool = [...first].sort((a, b) => b.rating - a.rating).slice(0, 12);
      const day = Math.floor(Date.now() / 864e5);
      hero = pool[day % Math.max(pool.length, 1)] || null;
    } catch { /* pas d'affiche */ }
  }
  const rows = [];
  const v = vodCats.slice(0, 8);
  const s = seriesCats.slice(0, 6);
  for (let i = 0; i < Math.max(v.length, s.length); i++) {
    if (v[i]) rows.push(lazyRow('vod', v[i]));
    if (s[i]) rows.push(lazyRow('series', s[i]));
  }
  const mine = myList.all().filter((i) => i.type !== 'live');
  const heroHtml = hero
    ? `<section class="hero">${remember(hero) && ''}<img src="${esc(api.img(hero.img))}" alt="">
        <div class="info"><h2>${esc(cleanTitle(hero.name))}</h2>
        <div class="actions">
          <button class="round" data-toggle-list="${hero.type}:${esc(hero.id)}">${icon(myList.has(hero) ? 'check' : 'add')}Ma liste</button>
          <button class="btn" data-play="${hero.type}:${esc(hero.id)}">${icon('play')}Lecture</button>
          <button class="round" data-open="${hero.type}:${esc(hero.id)}">${icon('info')}Infos</button>
        </div></div></section>`
    : '<div style="height:calc(var(--safe-top) + 72px)"></div>';
  app.innerHTML = shell(
    '#/accueil',
    heroHtml + installHint() + continueRow() + row('Ma liste', mine) + rows.join(''),
    { overlay: true },
  );
  watchLazyRows();
}

async function viewCatalog(kind, active, title) {
  app.innerHTML = shell(active, loading, { title });
  try {
    const cats = await api.categories(kind);
    app.innerHTML = shell(
      active,
      cats.length ? cats.map((c) => lazyRow(kind, c)).join('') : '<div class="hint">Rien à afficher pour le moment.</div>',
      { title },
    );
    watchLazyRows();
  } catch {
    app.innerHTML = shell(active, errorBox(), { title });
  }
}

async function viewCategory(kind, catId) {
  app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>${loading}`;
  try {
    const [cats, items] = await Promise.all([api.categories(kind), api.streams(kind, catId)]);
    const cat = cats.find((c) => c.id === catId);
    const shown = kind === 'live' ? items : groupVersions(items);
    app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>
      <div style="padding:calc(var(--safe-top) + 64px) 0 calc(var(--safe-bottom) + 24px)">
      <h3 class="section" style="margin-top:0">${esc(cleanTitle(cat?.name || ''))}</h3>
      <div class="grid">${shown.map((i) => card(i)).join('')}</div></div>`;
  } catch {
    app.innerHTML = errorBox();
  }
}

function viewMyList() {
  const mine = myList.all();
  const titles = mine.filter((i) => i.type !== 'live');
  const channels = mine.filter((i) => i.type === 'live');
  const custom = lists.all();
  const empty = !titles.length && !channels.length && !custom.length && !continueItems().length;
  const create = `<div style="padding:0 var(--gutter)"><button class="btn ghost" data-create-list>${icon('add')}Créer une liste</button></div>`;
  const body = empty
    ? `<div class="hint">${icon('bookmark')}<b style="color:var(--text)">Ta liste est vide</b>
        Appuie sur « Ma liste » sur un film ou une série pour le retrouver ici. Tu peux aussi créer tes propres listes, par exemple « Films de Noël ».
        <button class="btn ghost" data-create-list>${icon('add')}Créer une liste</button></div>`
    : continueRow() +
      row('Ma liste', titles) +
      custom
        .map((l) =>
          l.items.length
            ? row(l.name, l.items, { menu: l.id })
            : `<section class="row"><div class="row-head">${esc(l.name)}<button class="more" data-list-menu="${l.id}">${icon('more')}</button></div>
               <div style="padding:0 var(--gutter);color:var(--muted)">Liste vide. Sur un film ou une série, appuie sur « Ma liste » puis choisis « ${esc(l.name)} ».</div></section>`,
        )
        .join('') +
      row('Mes chaînes', channels) +
      create;
  app.innerHTML = shell('#/liste', body, { title: 'Ma liste' });
}

let searchTimer;
function viewSearch() {
  app.innerHTML = `<div class="search"><button class="icon-btn" onclick="history.back()">${icon('back')}</button>
    <input id="q" type="search" placeholder="Titre, chaîne…" autocomplete="off" autocapitalize="off"></div>
    <div id="results"><div class="hint">${icon('search')}Cherche un film, une série ou une chaîne.</div></div>`;
  const q = $('#q');
  setTimeout(() => q.focus(), 50);
  q.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => runSearch(q.value.trim()), 300);
  });
}

async function runSearch(text) {
  const out = $('#results');
  if (!out) return;
  if (text.length < 2) {
    out.innerHTML = `<div class="hint">${icon('search')}Cherche un film, une série ou une chaîne.</div>`;
    return;
  }
  out.innerHTML = loading;
  const needle = text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
  const match = (i) =>
    parseTitle(i.name).title.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').includes(needle);
  try {
    const [vod, series, live] = await Promise.all([
      api.allStreams('vod'),
      api.allStreams('series'),
      api.allStreams('live'),
    ]);
    if ($('#q')?.value.trim() !== text) return;
    const m = groupVersions(vod.filter(match)).slice(0, 60);
    const s = groupVersions(series.filter(match)).slice(0, 60);
    const l = live.filter(match).slice(0, 60);
    out.innerHTML =
      m.length + s.length + l.length
        ? `<div style="padding-top:12px">${row(`Films (${m.length})`, m)}${row(`Séries (${s.length})`, s)}${row(`Chaînes (${l.length})`, l)}</div>`
        : `<div class="hint">${icon('sad')}Aucun résultat pour « ${esc(text)} ».</div>`;
  } catch {
    out.innerHTML = errorBox();
  }
}

function errorBox() {
  return `<div class="hint">${icon('sad')}Impossible de joindre le serveur IPTV.<br>Vérifie ta connexion et réessaie.
    <button class="btn soft" onclick="location.reload()">Réessayer</button></div>`;
}

// ---------- Fiches ----------

async function findItem(type, id) {
  const hit = known.get(`${type}:${id}`);
  if (hit) return hit;
  const all = await api.allStreams(type);
  const found = all.find((i) => i.id === id);
  return found ? remember(found) : null;
}

function headHtml(backdrop, poster, title) {
  if (backdrop) {
    return `<div class="detail-head"><div class="bg" style="background-image:url('${esc(api.img(backdrop))}')"></div></div>`;
  }
  const p = api.img(poster);
  return `<div class="detail-head" style="height:calc(300px + var(--safe-top))">
    <div class="bg blur" style="background-image:url('${esc(p)}')"></div>
    <div class="poster">${p ? `<img src="${esc(p)}" alt="">` : `<div class="fallback">${esc(title)}</div>`}</div></div>`;
}

function metaHtml(rating, parts) {
  const r = rating > 0
    ? `<span class="star">${icon('star')}${rating.toFixed(1).replace('.', ',')}</span>`
    : '';
  return `<div class="meta">${r}${parts.filter(Boolean).map((p) => `<span>${esc(p)}</span>`).join('')}</div>`;
}

function listButton(item) {
  const on = lists.inAny(item);
  return `<button class="act ${on ? 'on' : ''}" data-pick-list="${item.type}:${esc(item.id)}">${icon(on ? 'check' : 'add')}Ma liste</button>`;
}

function playBlock(item, label) {
  const p = progress.get(item.type === 'episode' ? 'episode' : item.type, item.id);
  const pct = p && p.dur ? p.pos / p.dur : 0;
  const resuming = pct > 0.02 && pct < 0.95;
  return `<button class="btn block" style="margin-top:16px" data-play="${item.type}:${esc(item.id)}">${icon('play')}${resuming ? 'Reprendre' : label}</button>
    ${resuming ? `<div class="progress"><div class="track"><i style="width:${Math.round(pct * 100)}%"></i></div>Reste ${minutes(p.dur - p.pos)}</div>` : ''}`;
}

async function viewMovie(id) {
  app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>${loading}`;
  const item = await findItem('vod', id).catch(() => null);
  if (!item) {
    app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>${errorBox()}`;
    return;
  }
  let info = {};
  try {
    info = (await api.vodInfo(id))?.info || {};
  } catch { /* fiche minimale */ }
  const backdrop = Array.isArray(info.backdrop_path) ? info.backdrop_path[0] : info.backdrop_path;
  const poster = info.cover_big || info.movie_image || item.img;
  const rating = Number(info.rating) || item.rating || 0;
  const year = String(info.releasedate || info.release_date || '').slice(0, 4);
  const dur = Number(info.duration_secs) || 0;
  const genre = String(info.genre || '').split(/[,/|]/).map((g) => g.trim()).filter(Boolean).slice(0, 2).join(', ');
  const title = cleanTitle(item.name);
  const canPlay = api.safariCanPlay(item);

  app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>
    ${headHtml(backdrop, poster, title)}
    <div class="detail">
      <h2>${esc(title)}</h2>
      ${metaHtml(rating, [year, dur ? minutes(dur) : '', genre])}
      <div class="chips hidden" id="versions"></div>
      ${playBlock(item, 'Lecture')}
      ${canPlay ? '' : `<div class="note"><b>Ce film s'ouvre dans VLC.</b> Son format (${esc(String(item.ext).toUpperCase())}) n'est pas lu par l'iPhone dans une page web. Lecture l'ouvre dans l'app VLC, gratuite sur l'App Store.</div>`}
      <div class="acts">${listButton(item)}
        <a class="act" href="${esc(api.vlcUrl(item))}">${icon('vlc')}VLC</a></div>
      ${info.plot ? `<p class="plot">${esc(info.plot)}</p>` : ''}
      <div class="credits">${info.director ? `Réalisation : <b>${esc(info.director)}</b><br>` : ''}${info.cast ? `Avec : <b>${esc(info.cast)}</b>` : ''}</div>
    </div>
    <div id="related"></div><div style="height:calc(var(--safe-bottom) + 32px)"></div>`;

  // Autres versions (4K, UHD…) et rangée « Dans la même catégorie ».
  api.allStreams('vod').then((all) => {
    if (location.hash !== `#/film/${encodeURIComponent(id)}`) return;
    const key = parseTitle(item.name).key;
    const versions = all.filter((v) => parseTitle(v.name).key === key);
    if (versions.length > 1) {
      versions.sort((a, b) => qualityRank(a.name) - qualityRank(b.name) || a.name.localeCompare(b.name));
      const el = $('#versions');
      el.classList.remove('hidden');
      el.innerHTML = `<span class="lbl">Version</span>${versions
        .map((v) => {
          remember(v);
          const label = parseTitle(v.name).version + (api.safariCanPlay(v) ? '' : ' (VLC)');
          return `<button class="chip ${v.id === item.id ? 'on' : ''}" data-version="${esc(v.id)}">${esc(label)}</button>`;
        })
        .join('')}`;
    }
  }).catch(() => {});
  if (item.cat) {
    api.streams('vod', item.cat).then((list) => {
      const rel = groupVersions(list.filter((i) => i.id !== item.id)).slice(0, 20);
      const el = $('#related');
      if (el) el.innerHTML = row('Dans la même catégorie', rel);
    }).catch(() => {});
  }
}

async function viewSeries(id, season = null) {
  app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>${loading}`;
  const item = await findItem('series', id).catch(() => null);
  let data;
  try {
    data = await api.seriesInfo(id);
  } catch {
    app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>${errorBox()}`;
    return;
  }
  const info = data?.info || {};
  const base = item || remember({ type: 'series', id, name: info.name || '', img: info.cover || '' });
  const episodesBySeason = data?.episodes || {};
  const seasons = Object.keys(episodesBySeason).sort((a, b) => Number(a) - Number(b));
  const toEp = (e, s) =>
    remember({
      type: 'episode',
      id: String(e.id),
      ext: e.container_extension || 'mp4',
      name: `${cleanTitle(base.name)} · S${s} É${e.episode_num}`,
      epTitle: e.title || `Épisode ${e.episode_num}`,
      num: e.episode_num,
      season: s,
      seriesId: id,
      img: e.info?.movie_image || base.img,
      dur: Number(e.info?.duration_secs) || 0,
      plot: e.info?.plot || '',
    });
  const all = seasons.flatMap((s) => (episodesBySeason[s] || []).map((e) => toEp(e, s)));
  // Prochain épisode : après le dernier commencé, sinon le premier.
  const started = all
    .map((e) => ({ e, p: progress.get('episode', e.id) }))
    .filter((x) => x.p)
    .sort((a, b) => b.p.at - a.p.at)[0];
  let next = all[0];
  if (started) {
    const pct = started.p.dur ? started.p.pos / started.p.dur : 0;
    next = pct < 0.95 ? started.e : all[all.indexOf(started.e) + 1] || started.e;
  }
  const current = season || next?.season || seasons[0];
  const backdrop = Array.isArray(info.backdrop_path) ? info.backdrop_path[0] : '';
  const title = cleanTitle(base.name || info.name);
  const rating = Number(info.rating) || base.rating || 0;
  const year = String(info.releaseDate || info.release_date || '').slice(0, 4);
  const genre = String(info.genre || '').split(/[,/|]/).map((g) => g.trim()).filter(Boolean).slice(0, 2).join(', ');
  const eps = (episodesBySeason[current] || []).map((e) => toEp(e, current));

  app.innerHTML = `<a class="back" href="javascript:history.back()">${icon('back')}</a>
    ${headHtml(backdrop, info.cover || base.img, title)}
    <div class="detail">
      <h2>${esc(title)}</h2>
      ${metaHtml(rating, [year, seasons.length ? `${seasons.length} saison${seasons.length > 1 ? 's' : ''}` : '', genre])}
      ${next ? playBlock(next, `Lecture S${next.season} É${next.num}`) : ''}
      <div class="acts">${listButton(base)}</div>
      ${info.plot ? `<p class="plot">${esc(info.plot)}</p>` : ''}
      <div class="credits">${info.cast ? `Avec : <b>${esc(info.cast)}</b>` : ''}</div>
    </div>
    <h3 class="section">Épisodes</h3>
    ${seasons.length > 1 ? `<div class="chips" style="padding:0 var(--gutter);margin:0 0 10px">${seasons.map((s) => `<button class="chip ${s === current ? 'on' : ''}" data-season="${esc(s)}">Saison ${esc(s)}</button>`).join('')}</div>` : ''}
    <div class="episodes">${eps
      .map((e) => {
        const p = progress.get('episode', e.id);
        const pct = p && p.dur ? p.pos / p.dur : 0;
        return `<button class="episode" data-play="episode:${esc(e.id)}">
          <div class="thumb">${e.img ? `<img loading="lazy" src="${esc(api.img(e.img))}" alt="" onerror="this.remove()">` : ''}
            <div class="play" style="position:absolute;inset:0;display:grid;place-items:center"><span style="width:34px;height:34px;border-radius:50%;border:2px solid #fff;background:#0007;display:grid;place-items:center">${icon('play')}</span></div>
            ${pct ? `<div class="bar" style="position:absolute;left:0;right:0;bottom:0;height:4px;background:#fff3"><i style="display:block;height:100%;background:var(--pink);width:${Math.round(pct * 100)}%"></i></div>` : ''}</div>
          <div><div class="t">${esc(e.num)}. ${esc(cleanTitle(e.epTitle))}</div>
          <div class="d">${e.dur ? minutes(e.dur) : ''}${api.safariCanPlay(e) ? '' : `${e.dur ? ' · ' : ''}s'ouvre dans VLC`}</div></div></button>`;
      })
      .join('')}</div>
    <div style="height:calc(var(--safe-bottom) + 32px)"></div>`;
  app.dataset.series = id;
}

// ---------- Lecture ----------

function play(item) {
  if (!api.safariCanPlay(item)) {
    openSheet(`<h4>Ouvrir dans VLC</h4>
      <p style="margin:0 20px 14px;color:var(--muted);line-height:1.45">Ce format n'est pas lu par l'iPhone dans une page web. Il s'ouvre dans l'app VLC (gratuite, sans pub).</p>
      <a class="item pink" href="${esc(api.vlcUrl(item))}">${icon('play')}<span class="txt"><div>Lire dans VLC</div></span></a>
      <a class="item" href="https://apps.apple.com/app/vlc-media-player/id650377962" target="_blank" rel="noopener">${icon('add')}<span class="txt"><div>Installer VLC</div><div>Une seule fois, depuis l'App Store</div></span></a>`);
    return;
  }
  const kind = item.type === 'episode' ? 'episode' : item.type;
  const saved = kind === 'live' ? null : progress.get(kind, item.id);
  const el = document.createElement('div');
  el.className = 'player';
  el.innerHTML = `<button class="back close" aria-label="Fermer">${icon('close')}</button>
    <video playsinline controls autoplay preload="auto"></video>`;
  document.body.appendChild(el);
  const video = $('video', el);
  video.src = api.relay(api.directUrl(item));
  let lastSave = 0;
  const save = () => {
    if (kind === 'live' || !video.duration || !isFinite(video.duration)) return;
    progress.set({
      type: kind,
      id: item.id,
      name: item.name,
      img: item.img,
      ext: item.ext,
      seriesId: item.seriesId,
      pos: video.currentTime,
      dur: video.duration,
    });
  };
  video.addEventListener('loadedmetadata', () => {
    if (saved && saved.dur && saved.pos / saved.dur < 0.95) video.currentTime = saved.pos;
  });
  video.addEventListener('timeupdate', () => {
    if (Date.now() - lastSave > 5000) {
      lastSave = Date.now();
      save();
    }
  });
  video.addEventListener('error', () => {
    const err = document.createElement('div');
    err.className = 'err';
    err.innerHTML = `${icon('sad')}<div>La vidéo ne se lance pas ici.</div>
      <a class="btn" href="${esc(api.vlcUrl(item))}">${icon('play')}Ouvrir dans VLC</a>`;
    el.appendChild(err);
  });
  const close = () => {
    save();
    video.pause();
    video.removeAttribute('src');
    video.load();
    el.remove();
    render();
  };
  $('.close', el).addEventListener('click', close);
  video.play().catch(() => {});
}

// ---------- Feuilles (listes, profil) ----------

function openSheet(html) {
  const back = document.createElement('div');
  back.className = 'sheet-back';
  back.innerHTML = `<div class="sheet"><div class="grip"></div>${html}</div>`;
  back.addEventListener('click', (e) => {
    if (e.target === back) back.remove();
  });
  document.body.appendChild(back);
  return back;
}

function pickList(item) {
  const draw = () => {
    const check = (on) => icon(on ? 'checkCircle' : 'circle', `chk ${on ? 'on' : ''}`);
    return `<h4>Ajouter à une liste</h4>
      <button class="item" data-sheet-mylist>${icon('bookmark')}<span class="txt"><div>Ma liste</div></span>${check(myList.has(item))}</button>
      ${lists.all().map((l) => {
        const on = l.items.some((i) => i.type === item.type && i.id === item.id);
        return `<button class="item" data-sheet-list="${l.id}">${icon('list')}<span class="txt"><div>${esc(l.name)}</div><div>${l.items.length ? `${l.items.length} titre${l.items.length > 1 ? 's' : ''}` : 'Vide'}</div></span>${check(on)}</button>`;
      }).join('')}
      <button class="item pink" data-sheet-new>${icon('add')}<span class="txt"><div>Nouvelle liste</div></span></button>`;
  };
  const back = openSheet(draw());
  const sheet = $('.sheet', back);
  const redraw = () => {
    sheet.innerHTML = `<div class="grip"></div>${draw()}`;
  };
  sheet.addEventListener('click', (e) => {
    const t = e.target.closest('button');
    if (!t) return;
    if (t.hasAttribute('data-sheet-mylist')) myList.toggle(item);
    else if (t.dataset.sheetList) lists.toggle(t.dataset.sheetList, item);
    else if (t.hasAttribute('data-sheet-new')) {
      const name = prompt('Nom de la nouvelle liste (ex. Films de Noël)');
      if (!name || !name.trim()) return;
      const l = lists.create(name);
      lists.toggle(l.id, item);
    }
    redraw();
  });
  const obs = new MutationObserver(() => {
    if (!document.body.contains(back)) {
      obs.disconnect();
      const on = lists.inAny(item);
      document.querySelectorAll(`[data-pick-list="${item.type}:${CSS.escape(item.id)}"]`).forEach((b) => {
        b.classList.toggle('on', on);
        b.innerHTML = `${icon(on ? 'check' : 'add')}Ma liste`;
      });
    }
  });
  obs.observe(document.body, { childList: true });
}

function listMenu(id) {
  const l = lists.all().find((x) => x.id === id);
  if (!l) return;
  const back = openSheet(`<h4>${esc(l.name)}</h4>
    <button class="item" data-rename>${icon('edit')}<span class="txt"><div>Renommer</div></span></button>
    <button class="item" data-delete>${icon('trash')}<span class="txt"><div>Supprimer la liste</div><div>Les films restent disponibles</div></span></button>`);
  back.addEventListener('click', (e) => {
    const t = e.target.closest('button');
    if (!t) return;
    if (t.hasAttribute('data-rename')) {
      const name = prompt('Nouveau nom', l.name);
      if (name && name.trim()) lists.rename(id, name);
    } else if (t.hasAttribute('data-delete')) {
      if (!confirm(`Supprimer la liste « ${l.name} » ?`)) return;
      lists.remove(id);
    }
    back.remove();
    render();
  });
}

function profileMenu() {
  const p = profiles.current;
  const back = openSheet(`<h4>${esc(p.name)}</h4>
    <button class="item" data-switch>${icon('swap')}<span class="txt"><div>Changer de profil</div></span></button>`);
  back.addEventListener('click', (e) => {
    if (e.target.closest('[data-switch]')) {
      back.remove();
      profiles.current = null;
      go('#/profils');
    }
  });
}

// ---------- Clics ----------

document.addEventListener('click', async (e) => {
  const t = e.target.closest('[data-open],[data-play],[data-toggle-list],[data-pick-list],[data-profile],[data-edit-profiles],[data-profile-menu],[data-create-list],[data-list-menu],[data-version],[data-season],[data-hide-install]');
  if (!t) return;
  const d = t.dataset;
  if (d.open) {
    const [type, id] = d.open.split(/:(.*)/s);
    const item = known.get(d.open);
    if (type === 'vod') go(`#/film/${encodeURIComponent(id)}`);
    else if (type === 'series') go(`#/serie/${encodeURIComponent(id)}`);
    else if (type === 'live' && item) play(item);
    else if (type === 'episode' && item) go(`#/serie/${encodeURIComponent(item.seriesId)}`);
  } else if (d.play) {
    const item = known.get(d.play);
    if (item) play(item);
  } else if (d.toggleList) {
    const item = known.get(d.toggleList);
    if (item) {
      toast(myList.toggle(item) ? 'Ajouté à Ma liste' : 'Retiré de Ma liste');
      render();
    }
  } else if (d.pickList) {
    const item = known.get(d.pickList);
    if (item) pickList(item);
  } else if (d.profile) {
    if (d.editing) {
      const p = profiles.all().find((x) => x.id === d.profile);
      if (p && confirm(`Supprimer le profil « ${p.name} » ?`)) profiles.remove(p.id);
      viewProfiles(true);
    } else {
      profiles.current = profiles.all().find((x) => x.id === d.profile);
      go('#/accueil');
    }
  } else if ('editProfiles' in d) {
    viewProfiles(!document.querySelector('[data-editing="1"]'));
  } else if ('profileMenu' in d) {
    profileMenu();
  } else if ('createList' in d) {
    const name = prompt('Nom de la nouvelle liste (ex. Films de Noël)');
    if (name && name.trim()) {
      lists.create(name);
      render();
    }
  } else if (d.listMenu) {
    listMenu(d.listMenu);
  } else if (d.version) {
    history.replaceState(null, '', `#/film/${encodeURIComponent(d.version)}`);
    render();
  } else if (d.season) {
    viewSeries(app.dataset.series, d.season);
  } else if ('hideInstall' in d) {
    localStorage.setItem('ltv.hideInstall', '1');
    t.remove();
  }
});

// ---------- Navigation ----------

function render() {
  observer?.disconnect();
  document.querySelectorAll('.sheet-back').forEach((el) => el.remove());
  window.scrollTo(0, 0);
  const hash = location.hash || '';
  const [, route, a, b] = hash.split('/').map(decodeURIComponent);
  if (route === 'ajouter') return viewAddProfile();
  if (!profiles.current || route === 'profils' || !route) {
    if (profiles.current && !route) return go('#/accueil');
    return viewProfiles();
  }
  switch (route) {
    case 'accueil': return viewHome();
    case 'films': return viewCatalog('vod', '#/films', 'Films');
    case 'series': return viewCatalog('series', '#/series', 'Séries');
    case 'tv': return viewCatalog('live', '#/tv', 'TV');
    case 'liste': return viewMyList();
    case 'recherche': return viewSearch();
    case 'film': return viewMovie(a);
    case 'serie': return viewSeries(a);
    case 'cat': return viewCategory(a, b);
    default: return go('#/accueil');
  }
}

window.addEventListener('hashchange', render);
// La barre du haut transparente (accueil) devient opaque quand on fait défiler.
window.addEventListener(
  'scroll',
  () => document.querySelector('.topbar.overlay')?.classList.toggle('solid', scrollY > 240),
  { passive: true },
);
render();

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').catch(() => {});
}
