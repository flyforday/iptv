import 'package:another_iptv_player/services/movie_versions.dart';
import 'package:another_iptv_player/utils/title_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deux films de même nom ne sont pas regroupés sans preuve', () {
    final items = ['|FR| Resident Evil', '|FR| Resident Evil (4K)'];
    expect(groupVersions(items, (i) => i).length, 2);
    final years = {'|FR| Resident Evil': '2002', '|FR| Resident Evil (4K)': '2025'};
    expect(groupVersions(items, (i) => i, identityOf: (i) => years[i]).length, 2);
    expect(groupVersions(items, (i) => i, identityOf: (_) => '2002').length, 1);
  });

  test('identité d\'un film', () {
    const a = FilmIdentity(tmdb: '1576', year: '2002', minutes: 100);
    const b = FilmIdentity(tmdb: '1576', year: '2002', minutes: 101);
    const c = FilmIdentity(tmdb: '1180000', year: '2025');
    const d = FilmIdentity(year: '2002', minutes: 99);
    expect(a.sameAs(b), isTrue);
    expect(a.sameAs(c), isFalse);
    expect(a.sameAs(d), isTrue);
    expect(const FilmIdentity().sameAs(const FilmIdentity()), isFalse);
    final parsed = FilmIdentity.fromVodInfo({
      'info': {'tmdb_id': 1576, 'releasedate': '2002-03-15', 'duration': '01:40:12'},
    });
    expect(parsed.tmdb, '1576');
    expect(parsed.year, '2002');
    expect(parsed.minutes, 100);
  });

  test('qualité lue dans le nom de catégorie', () {
    expect(qualityTagsIn('|FR| FILMS 4K LIGHT'), ['4K Light']);
    expect(qualityTagsIn('FR - UHD 2160p'), ['UHD', '4K']);
    expect(qualityTagsIn('Films Action'), isEmpty);
    expect(qualityTagsIn('THRILLER | HD'), ['HD']);
  });
}
