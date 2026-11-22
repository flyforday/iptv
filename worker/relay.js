// Relais Lemaire TV (Cloudflare Workers ou Pages Functions).
//
// Safari sur iPhone refuse de lire, depuis un site sécurisé (https), les
// vidéos et les données envoyées en « http » par les fournisseurs IPTV, et
// ceux-ci n'autorisent pas les appels depuis une page web (CORS). Le relais
// récupère la ressource pour le téléphone :
//
//   /p/http/serveur.net:8080/player_api.php?username=…  →  http://serveur.net:8080/player_api.php?username=…
//
// Les listes de lecture HLS (.m3u8) sont réécrites pour que les segments
// passent eux aussi par le relais. Rien n'est stocké ni journalisé ici.

// Chemins IPTV acceptés (pour ne pas servir de relais ouvert à tout le web).
const ALLOWED = [
  /^\/player_api\.php$/,
  /^\/get\.php$/,
  /^\/xmltv\.php$/,
  /^\/live\//,
  /^\/movie\//,
  /^\/series\//,
  /^\/hls\//,
  /^\/hlsr\//,
  /^\/play\//,
  /^\/timeshift\//,
  /^\/[^/]+\/[^/]+\/\d+(\.(ts|m3u8))?$/, // /user/pass/123 (direct live)
  /\.(m3u8|ts|aac|m4s|mp4|m4v|mov|mkv|avi|vtt)$/i,
  /\.(jpe?g|png|webp|gif)$/i,
];

const PASS_HEADERS = ['range', 'accept', 'if-range'];

/** parts = [scheme, host, ...chemin] (segments décodés). */
export async function relay(request, parts) {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Méthode non autorisée', { status: 405 });
  }
  const [scheme, host, ...rest] = parts;
  if (!['http', 'https'].includes(scheme) || !host) {
    return new Response('Adresse invalide', { status: 400 });
  }
  const path = '/' + rest.map(encodeURIComponent).join('/').replace(/%2C/g, ',');
  const rawPath = '/' + rest.join('/');
  if (!ALLOWED.some((re) => re.test(rawPath))) {
    return new Response('Chemin non autorisé', { status: 403 });
  }

  const incoming = new URL(request.url);
  const target = `${scheme}://${host}${path}${incoming.search}`;

  const headers = new Headers();
  for (const h of PASS_HEADERS) {
    const v = request.headers.get(h);
    if (v) headers.set(h, v);
  }
  // Certains fournisseurs refusent les navigateurs inconnus.
  headers.set('user-agent', 'VLC/3.0.20 LibVLC/3.0.20');

  let upstream;
  try {
    upstream = await fetch(target, {
      method: request.method,
      headers,
      redirect: 'follow',
      // Les vidéos peuvent être longues à démarrer, pas les réponses de l'API.
      signal: AbortSignal.timeout(/\.php$/.test(rawPath) ? 45000 : 60000),
    });
  } catch (e) {
    const why = e && e.name === 'TimeoutError' ? 'le serveur ne répond pas (délai dépassé)' : (e && e.message) || String(e);
    return new Response(`Relais : serveur IPTV injoignable (${why})`, {
      status: 502,
      headers: { 'access-control-allow-origin': '*' },
    });
  }

  // 407 (« authentification proxy requise ») fait échouer Safari sans
  // message : on le transforme en erreur lisible.
  if (upstream.status === 407) {
    return new Response(
      'Le fournisseur IPTV refuse la connexion passant par le relais (code 407 : il bloque les adresses des serveurs).',
      { status: 502, headers: { 'access-control-allow-origin': '*', 'x-relais-erreur': '407' } },
    );
  }

  const out = new Headers();
  // Si le fournisseur compresse (gzip), le corps est décompressé ici : la
  // longueur annoncée ne correspond plus, et Safari coupe la connexion.
  const compressed = !!upstream.headers.get('content-encoding');
  for (const h of [
    'content-type',
    ...(compressed ? [] : ['content-length']),
    'content-range',
    'accept-ranges',
    'last-modified',
    'etag',
  ]) {
    const v = upstream.headers.get(h);
    if (v) out.set(h, v);
  }
  out.set('access-control-allow-origin', '*');
  out.set('cache-control', 'no-store');

  const type = (upstream.headers.get('content-type') || '').toLowerCase();
  const finalUrl = new URL(upstream.url || target);
  const isPlaylist =
    /\.m3u8$/i.test(finalUrl.pathname) ||
    type.includes('mpegurl') ||
    type.includes('x-mpegurl');

  if (isPlaylist && upstream.ok && request.method === 'GET') {
    const text = await upstream.text();
    const proxied = (u) => {
      const abs = new URL(u, finalUrl);
      return `/p/${abs.protocol.replace(':', '')}/${abs.host}${abs.pathname}${abs.search}`;
    };
    const rewritten = text
      .split('\n')
      .map((line) => {
        const t = line.trim();
        if (!t) return line;
        if (t.startsWith('#')) {
          // URI="…" dans les balises (clés, sous-titres, pistes audio).
          return line.replace(/URI="([^"]+)"/g, (_, u) => `URI="${proxied(u)}"`);
        }
        return proxied(t);
      })
      .join('\n');
    out.delete('content-length');
    out.set('content-type', 'application/vnd.apple.mpegurl');
    return new Response(rewritten, { status: upstream.status, headers: out });
  }

  if (/\.php$/.test(rawPath) && request.method === 'GET') {
    // Réponses de l'API : lues en entier ici, pour qu'une coupure du
    // fournisseur donne un message clair au lieu d'une erreur réseau.
    let text;
    try {
      text = await upstream.text();
    } catch (e) {
      return new Response(`Relais : réponse du serveur IPTV interrompue (${(e && e.message) || e})`, {
        status: 502,
        headers: { 'access-control-allow-origin': '*' },
      });
    }
    out.delete('content-length');
    out.set('x-relais-url-finale', new URL(upstream.url || target).host);
    return new Response(text, { status: upstream.status, headers: out });
  }

  return new Response(upstream.body, { status: upstream.status, headers: out });
}

/**
 * Diagnostic sans identifiants : /diag/http/serveur.net → ce que le relais
 * obtient en appelant player_api.php sans codes (statut, en-têtes, début).
 */
export async function diag(scheme, host) {
  const out = { target: `${scheme}://${host}/player_api.php`, etapes: [] };
  // Chaque redirection, chronométrée, pour voir laquelle est lente.
  let url = out.target;
  for (let i = 0; i < 6 && url; i++) {
    const t0 = Date.now();
    try {
      const r = await fetch(url, {
        headers: { 'user-agent': 'VLC/3.0.20 LibVLC/3.0.20' },
        redirect: 'manual',
        signal: AbortSignal.timeout(25000),
      });
      const loc = r.headers.get('location');
      out.etapes.push({ url: url.replace(/\?.*$/, ''), status: r.status, ms: Date.now() - t0, vers: loc && loc.replace(/\?.*$/, '') });
      url = loc ? new URL(loc, url).toString() : null;
    } catch (e) {
      out.etapes.push({ url, erreur: String((e && e.message) || e), ms: Date.now() - t0 });
      url = null;
    }
  }
  const t0 = Date.now();
  try {
    const r = await fetch(out.target, {
      headers: { 'user-agent': 'VLC/3.0.20 LibVLC/3.0.20' },
      redirect: 'follow',
    });
    out.status = r.status;
    out.finalUrl = r.url;
    out.headers = Object.fromEntries(
      ['content-type', 'content-encoding', 'content-length', 'server', 'location'].map((h) => [h, r.headers.get(h)]),
    );
    out.body = (await r.text()).slice(0, 300);
    out.msTotal = Date.now() - t0;
  } catch (e) {
    out.error = String((e && e.message) || e);
  }
  return new Response(JSON.stringify(out, null, 2), {
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

/**
 * Diagnostic avec les codes de l'utilisateur, sans jamais renvoyer leur
 * valeur : statuts, en-têtes et forme de la réponse (clés JSON seulement).
 */
export async function diagCodes(scheme, host, search, ua) {
  const agents = {
    vlc: 'VLC/3.0.20 LibVLC/3.0.20',
    android: 'Dart/3.9 (dart:io)',
    safari: ua || 'Mozilla/5.0',
    aucun: '',
  };
  const res = {};
  for (const [nom, agent] of Object.entries(agents)) {
    res[nom] = await diagOnce(scheme, host, search, agent);
  }
  return new Response(JSON.stringify(res, null, 1), {
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

async function diagOnce(scheme, host, search, agent) {
  const out = { etapes: [] };
  const hide = (u) => String(u).replace(/\?.*$/, '?…');
  let url = `${scheme}://${host}/player_api.php${search}`;
  for (let i = 0; i < 6 && url; i++) {
    const t0 = Date.now();
    try {
      const r = await fetch(url, {
        headers: agent ? { 'user-agent': agent } : {},
        redirect: 'manual',
        signal: AbortSignal.timeout(25000),
      });
      const loc = r.headers.get('location');
      const step = { url: hide(url), status: r.status, ms: Date.now() - t0 };
      if (loc) {
        step.vers = hide(new URL(loc, url));
        url = new URL(loc, url).toString();
      } else {
        url = null;
        step.acao = r.headers.get('access-control-allow-origin');
        let body = '';
        try {
          body = await r.text();
          step.taille = body.length;
        } catch (e) {
          step.erreurCorps = String((e && e.message) || e);
        }
        try {
          const j = JSON.parse(body);
          step.json = Object.fromEntries(
            Object.entries(j).map(([k, v]) => [k, v && typeof v === 'object' ? Object.keys(v) : typeof v]),
          );
          if (j.user_info) {
            step.auth = j.user_info.auth;
            step.statut = j.user_info.status;
            step.maxConnexions = j.user_info.max_connections;
            step.connexionsActives = j.user_info.active_cons;
          }
        } catch {
          step.debut = body.slice(0, 120).replace(/[A-Za-z0-9]{8,}/g, '•••');
        }
      }
      out.etapes.push(step);
    } catch (e) {
      out.etapes.push({ url: hide(url), erreur: String((e && e.message) || e), ms: Date.now() - t0 });
      url = null;
    }
  }
  const last = out.etapes[out.etapes.length - 1] || {};
  return { status: last.status, erreur: last.erreur, auth: last.auth, statut: last.statut, max: last.maxConnexions, actives: last.connexionsActives, acao: last.acao, taille: last.taille, debut: last.debut };
}
