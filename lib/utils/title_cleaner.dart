/// Nettoyage des titres envoyés par les fournisseurs IPTV.
///
/// Les serveurs renvoient souvent le même film plusieurs fois :
/// « |FR| Resident Evil », « |FR| Resident Evil (4K) »,
/// « |FR| Resident Evil (UHD) ». On affiche un titre propre, on regroupe
/// les versions sous une même clé et on garde la mention de qualité pour
/// laisser choisir la version sur la fiche.
class TitleInfo {
  /// Titre à afficher : sans préfixe de langue ni mention de qualité.
  final String title;

  /// Mentions retirées (« 4K », « UHD », « VOSTFR »…), dans l'ordre.
  final List<String> tags;

  /// Clé de regroupement : deux versions d'un même film ont la même clé.
  final String key;

  const TitleInfo._(this.title, this.tags, this.key);

  /// Nom court de la version, pour le choix sur la fiche.
  String get versionLabel => tags.isEmpty ? 'Standard' : tags.join(' · ');

  static final _cache = <String, TitleInfo>{};

  factory TitleInfo.parse(String raw) {
    final cached = _cache[raw];
    if (cached != null) return cached;
    final info = _parse(raw);
    if (_cache.length > 20000) _cache.clear();
    _cache[raw] = info;
    return info;
  }

  // Codes de langue ou de pays placés devant le titre par les fournisseurs.
  static const _langCodes =
      'FR|EN|UK|US|DE|ES|IT|PT|NL|AR|TR|BE|CH|CA|QC|AF|MULTI|VF|VFF|VFQ|VO|'
      'VOST|VOSTFR|4K|UHD|FHD|HD|SD|3D|NF|AMZ|DSNP|ATV|HBO|ALL';

  // « |FR| », « [FR] », « (FR) », « FR: », « FR - », « FR| » en tête.
  static final _prefix = RegExp(
    r'^\s*(?:[|\[(]\s*(?:' +
        _langCodes +
        r')\s*[|\])]|(?:' +
        _langCodes +
        r')\s*(?:\||:|-|–|»)\s)\s*',
  );

  // Toute balise entre |…| restante, ex. « |FR| |4K| Titre ».
  static final _pipeTag = RegExp(r'\|\s*([^|]{1,12}?)\s*\|');

  static const _qualityWords = [
    '4K LIGHT',
    '4K ULTRA HD',
    '4K ULTRAHD',
    'ULTRA HD',
    'ULTRAHD',
    '2160P',
    '1080P',
    '720P',
    '2160p',
    '1080p',
    '720p',
    '4K',
    'UHD',
    'FHD',
    'HDR10+',
    'HDR10',
    'HDR',
    'DOLBY VISION',
    'DV',
    'HEVC',
    'H265',
    'H.265',
    'X265',
    'HD',
    'SD',
    '3D',
    'MULTI',
    'MULTISUB',
    'VOSTFR',
    'VOST',
    'VFF',
    'VFQ',
    'VF',
    'VO',
    'ATMOS',
    'REMUX',
    'BLURAY',
  ];

  static final _qualityAlternation = _qualityWords
      .map(RegExp.escape)
      .join('|');

  // « (4K) », « [UHD] », « - 4K », « 4K » en fin de titre.
  static final _suffix = RegExp(
    r'(?:\s*[\(\[]\s*(' +
        _qualityAlternation +
        r')\s*[\)\]]|\s*(?:-|–|\|)?\s+(' +
        _qualityAlternation +
        r'))\s*$',
  );

  static TitleInfo _parse(String raw) {
    var s = raw.trim();
    final tags = <String>[];

    // Préfixes de langue répétés (« |FR| |4K| … »).
    for (var i = 0; i < 4; i++) {
      final m = _prefix.firstMatch(s);
      if (m == null) break;
      final code = m
          .group(0)!
          .replaceAll(RegExp(r'[|\[\]():\-–»\s]'), '')
          .toUpperCase();
      if (_isQuality(code)) tags.add(_pretty(code));
      s = s.substring(m.end);
    }
    s = s.replaceAllMapped(_pipeTag, (m) {
      final code = m.group(1)!.trim().toUpperCase();
      if (_isQuality(code)) tags.add(_pretty(code));
      return ' ';
    });

    // Mentions de qualité en fin de titre, éventuellement enchaînées.
    final suffixTags = <String>[];
    for (var i = 0; i < 4; i++) {
      final m = _suffix.firstMatch(s);
      if (m == null || m.start == 0) break;
      suffixTags.insert(0, _pretty((m.group(1) ?? m.group(2))!));
      s = s.substring(0, m.start);
    }
    tags.addAll(suffixTags);

    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'^[\-–:|•]+\s*|\s*[\-–:|•]+$'), '').trim();
    if (s.isEmpty) s = raw.trim();

    return TitleInfo._(s, tags, _keyOf(s));
  }

  static bool _isQuality(String code) =>
      _qualityWords.contains(code.toUpperCase());

  static String _pretty(String tag) {
    final t = tag.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    switch (t) {
      case '4K ULTRA HD':
      case '4K ULTRAHD':
      case 'ULTRA HD':
      case 'ULTRAHD':
        return 'UHD';
      case '4K LIGHT':
        return '4K Light';
      case '2160P':
        return '4K';
      case '1080P':
        return 'Full HD';
      case 'FHD':
        return 'Full HD';
      case '720P':
        return 'HD';
      case 'MULTI':
      case 'MULTISUB':
        return 'Multi';
      case 'DOLBY VISION':
        return 'Dolby Vision';
      case 'ATMOS':
        return 'Atmos';
      default:
        return t;
    }
  }

  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
    'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  };

  static String _keyOf(String title) {
    final lower = title.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final mapped = _accents[ch] ?? ch;
      if (RegExp(r'[a-z0-9]').hasMatch(mapped)) b.write(mapped);
    }
    return b.isEmpty ? lower : b.toString();
  }
}

/// Titre à afficher, sans « |FR| » ni « (4K) ».
String cleanTitle(String raw) => TitleInfo.parse(raw).title;

/// Garde un seul élément par titre : la première version rencontrée
/// représente les autres (qualités, langues).
/// [scopeOf] sépare des groupes qui ne doivent pas se mélanger (ex. un film
/// et une série du même nom).
List<T> groupVersions<T>(
  Iterable<T> items,
  String Function(T) nameOf, {
  String Function(T)? scopeOf,
}) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in items) {
    final scope = scopeOf == null ? '' : '${scopeOf(item)}:';
    if (seen.add(scope + TitleInfo.parse(nameOf(item)).key)) out.add(item);
  }
  return out;
}
