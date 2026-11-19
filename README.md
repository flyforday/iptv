# Famille TV

App mobile (Android et iPhone, téléphone et tablette) pour regarder les films,
séries et chaînes de son propre abonnement IPTV (codes Xtream ou lien M3U).
Usage familial, hors stores, sans pub. Chacun ajoute ses propres codes dans
l'app : aucun identifiant n'est stocké dans ce dépôt.

Basée sur [Another IPTV Player](https://github.com/bsogulcan/another-iptv-player)
(licence MIT, voir `LICENSE`), version Flutter, reprise au commit `d342d46`.

## Installer

Les fichiers sont dans l'onglet **Releases** du dépôt (fabriqués automatiquement
à chaque mise à jour de `main`).

- **Android** : télécharger `FamilleTV.apk` sur le téléphone, l'ouvrir et
  autoriser l'installation d'applications inconnues.
- **iPhone / iPad** : télécharger `FamilleTV.ipa` sur un ordinateur et
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
