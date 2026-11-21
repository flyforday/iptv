// Lemaire TV sur Cloudflare Workers : les fichiers de web/ sont servis tels
// quels, et /p/… passe par le relais vers le fournisseur IPTV.
import { relay } from './relay.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/p/')) {
      const parts = url.pathname.slice(3).split('/').map((s) => {
        try { return decodeURIComponent(s); } catch { return s; }
      });
      return relay(request, parts);
    }
    return env.ASSETS.fetch(request);
  },
};
