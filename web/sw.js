// Service worker minimal : il ne touche à aucune requête, tout passe par le
// réseau (Safari refusait d'ouvrir la page quand l'ancien renvoyait une réponse
// vide). Il efface aussi les caches laissés par les versions précédentes.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});
