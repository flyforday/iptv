// Accès à l'API Xtream Codes du fournisseur, via le relais /p/ du site.

import { profiles } from './store.js';
import { parseTitle } from './titles.js';

/** Adresse relayée : http://h:8080/x?y → /p/http/h:8080/x?y */
export function relay(url) {
  if (!url) return '';
  try {
    const u = new URL(url);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return url;
    return `/p/${u.protocol.replace(':', '')}/${u.host}${u.pathname}${u.search}`;
  } catch {
    return url;
  }
}

/** Image : les adresses https se chargent directement, les http via le relais. */
export function img(url) {
  if (!url) return '';
  return url.startsWith('https://') ? url : relay(url);
}

export function normalizeServer(raw) {
  let s = String(raw || '').trim();
  if (!s) return '';
  if (!/^https?:\/\//i.test(s)) s = 'http://' + s;
  try {
    const u = new URL(s);
    return `${u.protocol}//${u.host}`;
  } catch {
    return '';
  }
}

/** Lien M3U « …/get.php?username=…&password=… » → codes Xtream. */
export function fromM3uLink(text) {
  try {
    const u = new URL(String(text).trim());
    const user = u.searchParams.get('username');
    const pass = u.searchParams.get('password');
    if (!user || !pass) return null;
    return { server: `${u.protocol}//${u.host}`, user, pass };
  } catch {
    return null;
  }
}

async function call(p, action, extra = {}) {
  const q = new URLSearchParams({ username: p.user, password: p.pass });
  if (action) q.set('action', action);
  for (const [k, v] of Object.entries(extra)) q.set(k, v);
  let res;
  try {
    res = await fetch(relay(`${p.server}/player_api.php?${q}`));
  } catch {
    throw new Error('réseau : pas de connexion internet ?');
  }
  const text = await res.text();
  const brief = () => text.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 120);
  if (!res.ok) throw new Error(`HTTP ${res.status}${text ? ' : ' + brief() : ''}`);
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(text.trim() ? `réponse inattendue : ${brief()}` : 'réponse vide du serveur');
  }
}

export async function login(server, user, pass) {
  const data = await call({ server, user, pass }, null);
  if (!data || !data.user_info || Number(data.user_info.auth) === 0) {
    throw new Error('codes');
  }
  return data;
}

// ---------- Cache local (IndexedDB) pour les grosses listes ----------

const DB = 'lemaire-tv';
function idb() {
  return new Promise((resolve, reject) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => r.result.createObjectStore('kv');
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}
async function cacheGet(key) {
  try {
    const db = await idb();
    return await new Promise((res) => {
      const t = db.transaction('kv').objectStore('kv').get(key);
      t.onsuccess = () => res(t.result || null);
      t.onerror = () => res(null);
    });
  } catch {
    return null;
  }
}
async function cacheSet(key, value) {
  try {
    const db = await idb();
    db.transaction('kv', 'readwrite').objectStore('kv').put(value, key);
  } catch {
    /* pas de cache : tant pis */
  }
}

const memory = new Map();
const TTL = 6 * 3600 * 1000;

async function cached(key, loader, ttl = TTL) {
  if (memory.has(key)) return memory.get(key);
  const hit = await cacheGet(key);
  if (hit && Date.now() - hit.at < ttl) {
    memory.set(key, hit.data);
    return hit.data;
  }
  const data = await loader();
  memory.set(key, data);
  cacheSet(key, { at: Date.now(), data });
  return data;
}

// ---------- Catalogue ----------

const ACTIONS = {
  vod: ['get_vod_categories', 'get_vod_streams'],
  series: ['get_series_categories', 'get_series'],
  live: ['get_live_categories', 'get_live_streams'],
};

function norm(kind, s) {
  if (kind === 'vod') {
    return {
      type: 'vod',
      id: String(s.stream_id),
      name: s.name || '',
      img: s.stream_icon || '',
      ext: s.container_extension || 'mp4',
      rating: Number(s.rating_5based) * 2 || Number(s.rating) || 0,
      cat: String(s.category_id ?? ''),
      added: Number(s.added) || 0,
    };
  }
  if (kind === 'series') {
    return {
      type: 'series',
      id: String(s.series_id),
      name: s.name || '',
      img: s.cover || '',
      rating: Number(s.rating_5based) * 2 || Number(s.rating) || 0,
      cat: String(s.category_id ?? ''),
      plot: s.plot || '',
      genre: s.genre || '',
      year: (s.releaseDate || s.release_date || '').slice(0, 4),
      backdrop: Array.isArray(s.backdrop_path) ? s.backdrop_path[0] : '',
    };
  }
  return {
    type: 'live',
    id: String(s.stream_id),
    name: s.name || '',
    img: s.stream_icon || '',
    cat: String(s.category_id ?? ''),
  };
}

const key = (p, k) => `${p.id}:${k}`;

export function categories(kind) {
  const p = profiles.current;
  return cached(key(p, `cats:${kind}`), async () => {
    const data = await call(p, ACTIONS[kind][0]);
    return (Array.isArray(data) ? data : []).map((c) => ({
      id: String(c.category_id),
      name: c.category_name || '',
    }));
  });
}

export function streams(kind, catId) {
  const p = profiles.current;
  return cached(key(p, `list:${kind}:${catId}`), async () => {
    const data = await call(p, ACTIONS[kind][1], { category_id: catId });
    return (Array.isArray(data) ? data : []).map((s) => norm(kind, s));
  });
}

/** Tout le catalogue d'un type (pour la recherche et les versions). */
export function allStreams(kind) {
  const p = profiles.current;
  return cached(key(p, `all:${kind}`), async () => {
    const data = await call(p, ACTIONS[kind][1]);
    return (Array.isArray(data) ? data : []).map((s) => norm(kind, s));
  });
}

export async function vodInfo(id) {
  const p = profiles.current;
  return cached(key(p, `vod:${id}`), () => call(p, 'get_vod_info', { vod_id: id }), 24 * 3600e3);
}

export async function seriesInfo(id) {
  const p = profiles.current;
  return cached(
    key(p, `series:${id}`),
    () => call(p, 'get_series_info', { series_id: id }),
    6 * 3600e3,
  );
}

// ---------- Même film ? ----------

/** Identité d'un film d'après sa fiche : identifiant TMDB, année, durée. */
export async function filmIdentity(id) {
  try {
    const info = (await vodInfo(id))?.info;
    if (!info || Array.isArray(info)) return {};
    let tmdb = String(info.tmdb_id ?? info.tmdb ?? '').trim();
    if (!tmdb || tmdb === '0' || tmdb === 'null') tmdb = '';
    const year = (String(info.releasedate || info.release_date || info.year || '').match(/(19|20)\d{2}/) || [])[0] || '';
    let minutes = Number(info.duration_secs) > 0 ? Math.floor(info.duration_secs / 60) : 0;
    const m = !minutes && String(info.duration || '').match(/^(\d+):(\d{2})/);
    if (m) minutes = Number(m[1]) * 60 + Number(m[2]);
    return { tmdb, year, minutes };
  } catch {
    return {};
  }
}

/** Même film seulement si une information fiable le confirme. */
export function sameFilm(a, b) {
  if (a.tmdb && b.tmdb) return a.tmdb === b.tmdb;
  if (a.year && b.year) {
    if (a.year !== b.year) return false;
    return a.minutes && b.minutes ? Math.abs(a.minutes - b.minutes) <= 6 : true;
  }
  return false;
}

/** Une vignette par film : fusion seulement si le fournisseur confirme. */
export async function groupFilms(items, maxLookups = 40) {
  const byKey = new Map();
  for (const i of items) {
    const k = parseTitle(i.name).key;
    if (!byKey.has(k)) byKey.set(k, []);
    byKey.get(k).push(i);
  }
  const toCheck = [...byKey.values()].filter((l) => l.length > 1).flat().slice(0, maxLookups);
  if (!toCheck.length) return items;
  const ids = new Map();
  await Promise.all(toCheck.map(async (i) => ids.set(i.id, await filmIdentity(i.id))));
  const dropped = new Set();
  for (const list of byKey.values()) {
    const kept = [];
    for (const i of list) {
      const id = ids.get(i.id);
      if (id && kept.some((k) => ids.get(k.id) && sameFilm(ids.get(k.id), id))) dropped.add(i);
      else kept.push(i);
    }
  }
  return items.filter((i) => !dropped.has(i));
}

// ---------- Adresses de lecture (directes, sans relais) ----------

export function directUrl(item) {
  const p = profiles.current;
  const base = `${p.server}`;
  if (item.type === 'live') return `${base}/live/${p.user}/${p.pass}/${item.id}.m3u8`;
  if (item.type === 'episode') {
    return `${base}/series/${p.user}/${p.pass}/${item.id}.${item.ext || 'mp4'}`;
  }
  return `${base}/movie/${p.user}/${p.pass}/${item.id}.${item.ext || 'mp4'}`;
}

/** Safari sait-il lire ce fichier ? (MKV, AVI… non) */
export function safariCanPlay(item) {
  if (item.type === 'live') return true;
  return ['mp4', 'm4v', 'mov', 'm3u8'].includes(String(item.ext || '').toLowerCase());
}

/** Ouvre la vidéo dans l'app VLC (gratuite sur l'App Store). */
export function vlcUrl(item) {
  const url = item.type === 'live'
    ? directUrl(item).replace(/\.m3u8$/, '.ts')
    : directUrl(item);
  return `vlc-x-callback://x-callback-url/stream?url=${encodeURIComponent(url)}`;
}
