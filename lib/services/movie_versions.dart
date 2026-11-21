import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/utils/title_cleaner.dart';

/// Ce qui permet de reconnaître un film, d'après la fiche du fournisseur
/// (get_vod_info) : identifiant TMDB, année de sortie, durée.
class FilmIdentity {
  final String? tmdb;
  final String? year;
  final int? minutes;

  const FilmIdentity({this.tmdb, this.year, this.minutes});

  bool get isEmpty => tmdb == null && year == null;

  /// Même film ? Seulement si une information fiable le confirme.
  bool sameAs(FilmIdentity other) {
    if (tmdb != null && other.tmdb != null) return tmdb == other.tmdb;
    if (year != null && other.year != null) {
      if (year != other.year) return false;
      if (minutes != null && other.minutes != null) {
        return (minutes! - other.minutes!).abs() <= 6;
      }
      return true;
    }
    return false;
  }

  static FilmIdentity fromVodInfo(Map<String, dynamic>? data) {
    final raw = data?['info'];
    if (raw is! Map) return const FilmIdentity();
    final info = Map<String, dynamic>.from(raw);
    String? tmdb = '${info['tmdb_id'] ?? info['tmdb'] ?? ''}'.trim();
    if (tmdb.isEmpty || tmdb == '0' || tmdb == 'null') tmdb = null;
    final year = yearOf(
      '${info['releasedate'] ?? info['release_date'] ?? info['year'] ?? ''}',
    );
    int? minutes;
    final secs = int.tryParse('${info['duration_secs'] ?? ''}');
    if (secs != null && secs > 0) {
      minutes = secs ~/ 60;
    } else {
      final m = RegExp(r'^(\d+):(\d{2})').firstMatch('${info['duration'] ?? ''}');
      if (m != null) {
        minutes = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      }
    }
    return FilmIdentity(tmdb: tmdb, year: year, minutes: minutes);
  }
}

/// Versions d'un même film (4K, UHD…), vérifiées auprès du fournisseur.
class MovieVersions {
  static final _cache = <String, Future<FilmIdentity>>{};

  static Future<FilmIdentity> identityOf(IptvRepository repo, String vodId) {
    return _cache.putIfAbsent(vodId, () async {
      try {
        return FilmIdentity.fromVodInfo(await repo.getVodInfo(vodId));
      } catch (_) {
        return const FilmIdentity();
      }
    });
  }

  /// Une seule vignette par film dans une liste de résultats : les éléments
  /// de même titre ne sont fusionnés que si le fournisseur confirme que c'est
  /// le même film. Dans le doute, tout reste affiché.
  static Future<List<T>> group<T>(
    IptvRepository repo,
    List<T> items, {
    required String Function(T) idOf,
    required String Function(T) nameOf,
    int maxLookups = 40,
  }) async {
    final byKey = <String, List<T>>{};
    for (final item in items) {
      byKey.putIfAbsent(TitleInfo.parse(nameOf(item)).key, () => []).add(item);
    }
    final toCheck = [
      for (final list in byKey.values)
        if (list.length > 1) ...list,
    ].take(maxLookups).toList();
    if (toCheck.isEmpty) return items;

    final ids = <String, FilmIdentity>{};
    await Future.wait(
      toCheck.map((i) async => ids[idOf(i)] = await identityOf(repo, idOf(i))),
    );

    final dropped = <T>{};
    for (final list in byKey.values) {
      if (list.length < 2) continue;
      final kept = <T>[];
      for (final item in list) {
        final id = ids[idOf(item)];
        final twin = id == null
            ? null
            : kept.where((k) {
                final kid = ids[idOf(k)];
                return kid != null && kid.sameAs(id);
              }).firstOrNull;
        if (twin == null) {
          kept.add(item);
        } else {
          dropped.add(item);
        }
      }
    }
    return items.where((i) => !dropped.contains(i)).toList();
  }
}
