import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Une version publiée sur GitHub (Releases).
class AppRelease {
  final int build;
  final String name;
  final String pageUrl;
  final String? apkUrl;
  final String? ipaUrl;

  const AppRelease({
    required this.build,
    required this.name,
    required this.pageUrl,
    this.apkUrl,
    this.ipaUrl,
  });
}

/// Mise à jour hors store : l'app lit la dernière Release GitHub, compare
/// son numéro à celui de l'app installée et propose de l'installer.
class UpdateService {
  /// Dépôt public où la fabrication automatique publie l'APK et l'IPA.
  static const releasesRepo = 'flyforday/iptv';

  static bool _checkedThisLaunch = false;

  /// Numéro de la Release : « v42 » → 42.
  static int? buildFromTag(String tag) =>
      int.tryParse(tag.replaceFirst(RegExp(r'^[vV]'), '').split('.').first);

  static Future<AppRelease?> latest() async {
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$releasesRepo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final build = buildFromTag(data['tag_name']?.toString() ?? '');
    if (build == null) return null;
    String? asset(String ext) {
      for (final a in (data['assets'] as List? ?? const [])) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (name.endsWith(ext)) return a['browser_download_url']?.toString();
      }
      return null;
    }

    return AppRelease(
      build: build,
      name: data['name']?.toString() ?? 'v$build',
      pageUrl: data['html_url']?.toString() ??
          'https://github.com/$releasesRepo/releases/latest',
      apkUrl: asset('.apk'),
      ipaUrl: asset('.ipa'),
    );
  }

  static Future<int> installedBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Au démarrage : une seule vérification par lancement, sans bruit si
  /// tout est à jour ou s'il n'y a pas de réseau.
  static Future<void> checkOnLaunch(BuildContext context) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;
    await check(context, silent: true);
  }

  /// [silent] : ne rien afficher si l'app est à jour ou en cas d'erreur.
  static Future<void> check(BuildContext context, {bool silent = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    AppRelease? release;
    int current = 0;
    try {
      release = await latest();
      current = await installedBuild();
    } catch (_) {
      release = null;
    }
    if (!context.mounted) return;
    if (release == null || release.build <= current) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              release == null
                  ? 'Impossible de vérifier les mises à jour.'
                  : 'Lemaire TV est à jour.',
            ),
          ),
        );
      }
      return;
    }
    await _offer(context, release);
  }

  static Future<void> _offer(BuildContext context, AppRelease release) async {
    final android = Platform.isAndroid;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: const Text('Nouvelle version'),
        content: Text(
          android
              ? 'Une nouvelle version de Lemaire TV est disponible. '
                    'Elle se télécharge et s’installe en un instant, '
                    'tes profils et tes listes sont conservés.'
              : 'Une nouvelle version de Lemaire TV est disponible. '
                    'Télécharge-la puis réinstalle-la avec AltStore '
                    'ou Sideloadly, comme la première fois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(android ? 'Mettre à jour' : 'Télécharger'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    if (!android || release.apkUrl == null) {
      await launchUrl(
        Uri.parse(release.ipaUrl ?? release.pageUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(url: release.apkUrl!),
    );
  }
}

/// Téléchargement de l'APK avec sa progression, puis installation.
class _DownloadDialog extends StatefulWidget {
  final String url;

  const _DownloadDialog({required this.url});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() {
      _error = null;
      _progress = null;
    });
    try {
      OtaUpdate()
          .execute(widget.url, destinationFilename: 'LemaireTV.apk')
          .listen(
            (event) {
              if (!mounted) return;
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  final p = double.tryParse(event.value ?? '');
                  setState(() => _progress = p == null ? null : p / 100);
                  break;
                case OtaStatus.INSTALLING:
                case OtaStatus.INSTALLATION_DONE:
                  Navigator.of(context).pop();
                  break;
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  setState(
                    () => _error =
                        'Autorise Lemaire TV à installer des applications '
                        '(Réglages > Applis > Lemaire TV > Installer des '
                        'applis inconnues), puis réessaie.',
                  );
                  break;
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  break;
                default:
                  setState(
                    () => _error =
                        'Le téléchargement a échoué. Vérifie ta connexion '
                        'et réessaie.',
                  );
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() => _error = 'Le téléchargement a échoué.');
              }
            },
          );
    } catch (_) {
      setState(() => _error = 'Le téléchargement a échoué.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return AlertDialog(
      title: Text(_error == null ? 'Téléchargement…' : 'Mise à jour'),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: p, minHeight: 6),
                ),
                const SizedBox(height: 10),
                Text(p == null ? 'Préparation…' : '${(p * 100).round()} %'),
              ],
            ),
      actions: [
        if (_error != null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          FilledButton(onPressed: _start, child: const Text('Réessayer')),
        ],
      ],
    );
  }
}
