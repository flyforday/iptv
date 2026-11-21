// Données gardées sur le téléphone uniquement (jamais envoyées ailleurs que
// chez le fournisseur IPTV) : profils, Ma liste, listes perso, reprise.

const read = (k, fallback) => {
  try {
    const v = localStorage.getItem(k);
    return v ? JSON.parse(v) : fallback;
  } catch {
    return fallback;
  }
};
const write = (k, v) => {
  try {
    localStorage.setItem(k, JSON.stringify(v));
  } catch {
    /* stockage plein ou désactivé */
  }
};

// ---------- Profils ----------

export const profiles = {
  all: () => read('ltv.profiles', []),
  save(list) {
    write('ltv.profiles', list);
  },
  add(p) {
    const list = profiles.all();
    list.push(p);
    profiles.save(list);
  },
  remove(id) {
    profiles.save(profiles.all().filter((p) => p.id !== id));
    for (const k of Object.keys(localStorage)) {
      if (k.startsWith(`ltv.${id}.`)) localStorage.removeItem(k);
    }
  },
  get current() {
    const id = read('ltv.current', null);
    return profiles.all().find((p) => p.id === id) || null;
  },
  set current(p) {
    write('ltv.current', p ? p.id : null);
  },
};

const pk = (name) => `ltv.${profiles.current?.id || 'x'}.${name}`;

// Élément enregistré : { type: 'vod'|'series'|'live', id, name, img, ext }

// ---------- Ma liste et listes perso ----------

export const myList = {
  all: () => read(pk('mylist'), []),
  has: (item) => myList.all().some((i) => i.type === item.type && i.id === item.id),
  toggle(item) {
    const list = myList.all();
    const idx = list.findIndex((i) => i.type === item.type && i.id === item.id);
    if (idx >= 0) list.splice(idx, 1);
    else list.unshift(slim(item));
    write(pk('mylist'), list);
    return idx < 0;
  },
};

export const lists = {
  all: () => read(pk('lists'), []),
  save: (l) => write(pk('lists'), l),
  create(name) {
    const l = lists.all();
    const list = { id: Date.now().toString(36), name: name.trim(), items: [] };
    l.push(list);
    lists.save(l);
    return list;
  },
  rename(id, name) {
    lists.save(lists.all().map((l) => (l.id === id ? { ...l, name: name.trim() } : l)));
  },
  remove(id) {
    lists.save(lists.all().filter((l) => l.id !== id));
  },
  toggle(id, item) {
    let added = false;
    lists.save(
      lists.all().map((l) => {
        if (l.id !== id) return l;
        const has = l.items.some((i) => i.type === item.type && i.id === item.id);
        added = !has;
        return {
          ...l,
          items: has
            ? l.items.filter((i) => !(i.type === item.type && i.id === item.id))
            : [slim(item), ...l.items],
        };
      }),
    );
    return added;
  },
  inAny: (item) =>
    myList.has(item) ||
    lists.all().some((l) => l.items.some((i) => i.type === item.type && i.id === item.id)),
};

// ---------- Reprise de lecture ----------

export const progress = {
  all: () => read(pk('progress'), []),
  get: (type, id) => progress.all().find((p) => p.type === type && p.id === id) || null,
  set(entry) {
    const all = progress.all().filter((p) => !(p.type === entry.type && p.id === entry.id));
    all.unshift({ ...entry, at: Date.now() });
    write(pk('progress'), all.slice(0, 60));
  },
  remove(type, id) {
    write(
      pk('progress'),
      progress.all().filter((p) => !(p.type === type && p.id === id)),
    );
  },
};

function slim(i) {
  return { type: i.type, id: String(i.id), name: i.name, img: i.img || '', ext: i.ext || '' };
}
