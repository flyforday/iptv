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
      signal: AbortSignal.timeout(/\.php$/.test(rawPath) ? 20000 : 60000),
    });
  } catch (e) {
    const why = e && e.name === 'TimeoutError' ? 'le serveur ne répond pas (délai dépassé)' : (e && e.message) || String(e);
    return new Response(`Relais : serveur IPTV injoignable (${why})`, {
      status: 502,
      headers: { 'access-control-allow-origin': '*' },
    });
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
  const out = { target: `${scheme}://${host}/player_api.php` };
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
  } catch (e) {
    out.error = String((e && e.message) || e);
  }
  return new Response(JSON.stringify(out, null, 2), {
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}
