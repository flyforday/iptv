var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// worker/relay.js
var ALLOWED = [
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
  /^\/[^/]+\/[^/]+\/\d+(\.(ts|m3u8))?$/,
  // /user/pass/123 (direct live)
  /\.(m3u8|ts|aac|m4s|mp4|m4v|mov|mkv|avi|vtt)$/i,
  /\.(jpe?g|png|webp|gif)$/i
];
var PASS_HEADERS = ["range", "accept", "if-range"];
async function relay(request, parts) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("M\xE9thode non autoris\xE9e", { status: 405 });
  }
  const [scheme, host, ...rest] = parts;
  if (!["http", "https"].includes(scheme) || !host) {
    return new Response("Adresse invalide", { status: 400 });
  }
  const path = "/" + rest.map(encodeURIComponent).join("/").replace(/%2C/g, ",");
  const rawPath = "/" + rest.join("/");
  if (!ALLOWED.some((re) => re.test(rawPath))) {
    return new Response("Chemin non autoris\xE9", { status: 403 });
  }
  const incoming = new URL(request.url);
  const target = `${scheme}://${host}${path}${incoming.search}`;
  const headers = new Headers();
  for (const h of PASS_HEADERS) {
    const v = request.headers.get(h);
    if (v) headers.set(h, v);
  }
  headers.set("user-agent", "VLC/3.0.20 LibVLC/3.0.20");
  let upstream;
  try {
    upstream = await fetch(target, {
      method: request.method,
      headers,
      redirect: "follow"
    });
  } catch (e) {
    return new Response(`Serveur IPTV injoignable depuis le relais (${e && e.message ? e.message : e})`, {
      status: 502,
      headers: { "access-control-allow-origin": "*" }
    });
  }
  const out = new Headers();
  const compressed = !!upstream.headers.get("content-encoding");
  for (const h of [
    "content-type",
    ...compressed ? [] : ["content-length"],
    "content-range",
    "accept-ranges",
    "last-modified",
    "etag"
  ]) {
    const v = upstream.headers.get(h);
    if (v) out.set(h, v);
  }
  out.set("access-control-allow-origin", "*");
  out.set("cache-control", "no-store");
  const type = (upstream.headers.get("content-type") || "").toLowerCase();
  const finalUrl = new URL(upstream.url || target);
  const isPlaylist = /\.m3u8$/i.test(finalUrl.pathname) || type.includes("mpegurl") || type.includes("x-mpegurl");
  if (isPlaylist && upstream.ok && request.method === "GET") {
    const text = await upstream.text();
    const proxied = /* @__PURE__ */ __name((u) => {
      const abs = new URL(u, finalUrl);
      return `/p/${abs.protocol.replace(":", "")}/${abs.host}${abs.pathname}${abs.search}`;
    }, "proxied");
    const rewritten = text.split("\n").map((line) => {
      const t = line.trim();
      if (!t) return line;
      if (t.startsWith("#")) {
        return line.replace(/URI="([^"]+)"/g, (_, u) => `URI="${proxied(u)}"`);
      }
      return proxied(t);
    }).join("\n");
    out.delete("content-length");
    out.set("content-type", "application/vnd.apple.mpegurl");
    return new Response(rewritten, { status: upstream.status, headers: out });
  }
  return new Response(upstream.body, { status: upstream.status, headers: out });
}
__name(relay, "relay");
async function diag(scheme, host) {
  const out = { target: `${scheme}://${host}/player_api.php` };
  try {
    const r = await fetch(out.target, {
      headers: { "user-agent": "VLC/3.0.20 LibVLC/3.0.20" },
      redirect: "follow"
    });
    out.status = r.status;
    out.finalUrl = r.url;
    out.headers = Object.fromEntries(
      ["content-type", "content-encoding", "content-length", "server", "location"].map((h) => [h, r.headers.get(h)])
    );
    out.body = (await r.text()).slice(0, 300);
  } catch (e) {
    out.error = String(e && e.message || e);
  }
  return new Response(JSON.stringify(out, null, 2), {
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
  });
}
__name(diag, "diag");

// worker/index.js
var worker_default = {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/p/")) {
      const parts = url.pathname.slice(3).split("/").map((s) => {
        try {
          return decodeURIComponent(s);
        } catch {
          return s;
        }
      });
      return relay(request, parts);
    }
    const d = url.pathname.match(/^\/diag\/(https?)\/([A-Za-z0-9.-]+(?::\d+)?)\/?$/);
    if (d) return diag(d[1], d[2]);
    return env.ASSETS.fetch(request);
  }
};

// ../../../root/.npm/_npx/c943b712072b77c4/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../root/.npm/_npx/c943b712072b77c4/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    const body = JSON.stringify(error);
    const headers = {
      "Content-Type": "application/json",
      "MF-Experimental-Error-Stack": "true"
    };
    const encoded = encodeURIComponent(body);
    if (encoded.length <= 8192) {
      headers["MF-Experimental-Error-Stack-Payload"] = encoded;
    }
    return new Response(body, { status: 500, headers });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-vVOt2h/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = worker_default;

// ../../../root/.npm/_npx/c943b712072b77c4/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-vVOt2h/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  scheduledTime;
  cron;
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
