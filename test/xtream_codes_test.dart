import 'package:another_iptv_player/ui/profiles/add_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrait les codes Xtream d’un lien M3U de fournisseur', () {
    final c = XtreamCodes.fromM3uLink(
      'http://exemple.net:8080/get.php?username=abc&password=xyz&type=m3u_plus&output=ts',
    );
    expect(c, isNotNull);
    expect(c!.server, 'http://exemple.net:8080');
    expect(c.username, 'abc');
    expect(c.password, 'xyz');
  });

  test('ignore une adresse de serveur simple', () {
    expect(XtreamCodes.fromM3uLink('http://exemple.net'), isNull);
    expect(XtreamCodes.fromM3uLink('exemple.net'), isNull);
  });

  test('normalise l’adresse du serveur', () {
    expect(XtreamCodes.normalizeServer(' exemple.net/ '), 'http://exemple.net');
    expect(
      XtreamCodes.normalizeServer('https://exemple.net:8443//'),
      'https://exemple.net:8443',
    );
  });
}
