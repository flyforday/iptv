// Lemaire TV sur Cloudflare Workers : les fichiers de web/ sont servis tels
// quels, et /p/… passe par le relais vers le fournisseur IPTV.
import { relay, diag, diagCodes } from './relay.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/p/')) {
      const parts = url.pathname.slice(3).split('/').map((s) => {
        try { return decodeURIComponent(s); } catch { return s; }
      });
      return relay(request, parts);
    }
    const d = url.pathname.match(/^\/diag\/(https?)\/([A-Za-z0-9.-]+(?::\d+)?)\/?$/);
    if (d) return diag(d[1], d[2]);
    const dc = url.pathname.match(/^\/diagcodes\/(https?)\/([A-Za-z0-9.-]+(?::\d+)?)\/?$/);
    if (dc) return diagCodes(dc[1], dc[2], url.search, request.headers.get('user-agent'));
    return env.ASSETS.fetch(request);
  },
};
