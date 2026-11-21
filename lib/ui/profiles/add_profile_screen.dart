import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/playlist_controller.dart';
import '../../models/api_configuration_model.dart';
import '../../models/playlist_model.dart';
import '../../repositories/iptv_repository.dart';
import '../../screens/m3u/new_m3u_playlist_screen.dart';
import '../../screens/xtream-codes/xtream_code_data_loader_screen.dart';

/// Codes Xtream trouvés dans un lien M3U de fournisseur
/// (…/get.php?username=…&password=…).
class XtreamCodes {
  final String server;
  final String username;
  final String password;

  const XtreamCodes(this.server, this.username, this.password);

  static XtreamCodes? fromM3uLink(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final user = uri.queryParameters['username'];
    final pass = uri.queryParameters['password'];
    if (user == null || pass == null || user.isEmpty || pass.isEmpty) {
      return null;
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return XtreamCodes('${uri.scheme}://${uri.host}$port', user, pass);
  }

  /// Adresse du serveur nettoyée : ajoute http:// si absent, retire le
  /// « / » final.
  static String normalizeServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

/// Ajout d'un profil : un prénom et les codes de l'abonnement IPTV.
class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({super.key});

  @override
  State<AddProfileScreen> createState() => _AddProfileScreenState();
}

class _AddProfileScreenState extends State<AddProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hidePass = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _onServerChanged(String value) {
    final codes = XtreamCodes.fromM3uLink(value);
    if (codes == null) return;
    setState(() {
      _server.text = codes.server;
      _user.text = codes.username;
      _pass.text = codes.password;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien reconnu : identifiant et mot de passe remplis.'),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final name = _name.text.trim();
    final server = XtreamCodes.normalizeServer(_server.text);
    final user = _user.text.trim();
    final pass = _pass.text.trim();

    try {
      final repository = IptvRepository(
        ApiConfig(baseUrl: server, username: user, password: pass),
        name,
      );
      final info = await repository.getPlayerInfo(forceRefresh: true);
      if (info == null) {
        setState(() {
          _busy = false;
          _error =
              'Connexion impossible. Vérifie l’adresse du serveur, '
              'l’identifiant et le mot de passe.';
        });
        return;
      }

      if (!mounted) return;
      final controller = Provider.of<PlaylistController>(
        context,
        listen: false,
      );
      final playlist = await controller.createPlaylist(
        name: name,
        type: PlaylistType.xtream,
        url: server,
        username: user,
        password: pass,
      );
      if (!mounted) return;
      if (playlist == null) {
        setState(() {
          _busy = false;
          _error = controller.error ?? 'Enregistrement impossible.';
        });
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => XtreamCodeDataLoaderScreen(playlist: playlist),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Connexion impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau profil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    'Entre les codes envoyés par ton fournisseur IPTV '
                    '(dans le mail d’abonnement, rubrique « Codes Xtream »).',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 24),
                  _label(context, 'Prénom'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Ex. Léo, Maman…',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Donne un nom à ce profil'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _label(context, 'Adresse du serveur'),
                  TextFormField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    onChanged: _onServerChanged,
                    decoration: const InputDecoration(
                      hintText: 'http://monserveur.net',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    validator: (v) {
                      final s = XtreamCodes.normalizeServer(v ?? '');
                      final uri = Uri.tryParse(s);
                      if (s.isEmpty) return 'Indique l’adresse du serveur';
                      if (uri == null || uri.host.isEmpty) {
                        return 'Adresse invalide';
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Astuce : tu peux aussi coller ici ton lien M3U, '
                      'les codes seront remplis tout seuls.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label(context, 'Identifiant'),
                  TextFormField(
                    controller: _user,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indique ton identifiant'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _label(context, 'Mot de passe'),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hidePass,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _hidePass = !_hidePass),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indique ton mot de passe'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Se connecter'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NewM3uPlaylistScreen(),
                        ),
                      ),
                      child: const Text('Je n’ai qu’un lien M3U ou un fichier'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tes codes restent sur ce téléphone et ne sont '
                          'envoyés qu’à ton fournisseur.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
