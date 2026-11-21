// Variante Cloudflare Pages : même relais que le Worker (worker/relay.js).
import { relay } from '../../../worker/relay.js';

export function onRequest({ request, params }) {
  return relay(request, Array.isArray(params.path) ? params.path : [params.path]);
}
