import 'package:another_iptv_player/utils/title_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retire le préfixe de langue et la qualité', () {
    final a = TitleInfo.parse('|FR| Resident Evil');
    final b = TitleInfo.parse('|FR| Resident Evil (4K)');
    final c = TitleInfo.parse('|FR| Resident Evil (UHD)');
    expect(a.title, 'Resident Evil');
    expect(b.title, 'Resident Evil');
    expect(c.title, 'Resident Evil');
    expect(a.key, b.key);
    expect(b.key, c.key);
    expect(a.versionLabel, 'Standard');
    expect(b.versionLabel, '4K');
    expect(c.versionLabel, 'UHD');
  });

  test('autres formats courants', () {
    expect(cleanTitle('FR: Le Roi Lion'), 'Le Roi Lion');
    expect(cleanTitle('[FR] Le Roi Lion - 4K'), 'Le Roi Lion');
    expect(cleanTitle('FR - Le Roi Lion [MULTI]'), 'Le Roi Lion');
    expect(cleanTitle('|4K| Avatar'), 'Avatar');
    expect(TitleInfo.parse('|4K| Avatar').versionLabel, '4K');
    expect(cleanTitle('Dune 2160p'), 'Dune');
    expect(cleanTitle('Spider-Man: No Way Home'), 'Spider-Man: No Way Home');
    expect(cleanTitle('It: Chapitre 2'), 'It: Chapitre 2');
    expect(cleanTitle('Northern Light'), 'Northern Light');
    expect(cleanTitle('|FR| Une chimère'), 'Une chimère');
    expect(TitleInfo.parse('Élémentaire').key,
        TitleInfo.parse('ELEMENTAIRE (4K)').key);
  });

  test('regroupe les versions', () {
    final names = [
      '|FR| Resident Evil',
      '|FR| Resident Evil (4K)',
      '|FR| Resident Evil (UHD)',
      '|FR| Madden',
    ];
    expect(groupVersions(names, (n) => n), [
      '|FR| Resident Evil',
      '|FR| Madden',
    ]);
  });
}
