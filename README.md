# Lemaire TV

App mobile (Android et iPhone, téléphone et tablette) pour regarder les films,
séries et chaînes de son propre abonnement IPTV (codes Xtream ou lien M3U).
Usage familial, hors stores, sans pub. Chacun ajoute ses propres codes dans
l'app : aucun identifiant n'est stocké dans ce dépôt.

Basée sur [Another IPTV Player](https://github.com/bsogulcan/another-iptv-player)
(licence MIT, voir `LICENSE`), version Flutter, reprise au commit `d342d46`.

## Installer

Les fichiers sont dans l'onglet **Releases** du dépôt (fabriqués automatiquement
à chaque mise à jour de `main`).

- **Android** : télécharger `LemaireTV.apk` sur le téléphone, l'ouvrir et
  autoriser l'installation d'applications inconnues.
- **iPhone / iPad** : télécharger `LemaireTV.ipa` sur un ordinateur et
  l'installer avec [Sideloadly](https://sideloadly.io) (Windows ou Mac) et un
  identifiant Apple gratuit. Avec un compte gratuit, Apple limite l'app à
  7 jours : il suffit de la réinstaller (ou d'utiliser AltStore, qui la
  renouvelle tout seul).

## Développer

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Version de Flutter utilisée : 3.35.7 (voir `.github/workflows/build.yml`).

## Version iPhone (web, gratuite)

Le dossier `web/` contient une version web de Lemaire TV pour iPhone : on
l'ouvre dans Safari puis « Partager > Sur l'écran d'accueil ». Elle est mise
en ligne gratuitement par Cloudflare Workers, relié à ce dépôt :

- Cloudflare > Workers & Pages > Créer > Worker > Importer un dépôt > `flyforday/iptv`
- Répertoire racine : vide (`/`), commande de build : aucune,
  commande de déploiement : `npx wrangler deploy` (lit `wrangler.jsonc`)

`worker/relay.js` est le relais `/p/…` qui permet à Safari de lire les flux
« http » du fournisseur (`web/functions/p/` en est la variante Pages). Les films en MKV/AVI s'ouvrent dans l'app VLC (gratuite).
