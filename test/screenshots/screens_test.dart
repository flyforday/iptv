// Captures d'écran du design avec des données fictives (aucun réseau).
//
//   flutter test test/screenshots --update-goldens --run-skipped
//
// Les images sont écrites dans test/screenshots/out/.
@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:another_iptv_player/models/category.dart';
import 'package:another_iptv_player/models/category_type.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/favorite.dart';
import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/series.dart';
import 'package:another_iptv_player/models/vod_streams.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/ui/detail/detail_view.dart';
import 'package:another_iptv_player/ui/detail/episodes_section.dart';
import 'package:another_iptv_player/ui/home/catalog_view.dart';
import 'package:another_iptv_player/ui/widgets/media_row.dart';
import 'package:another_iptv_player/ui/home/home_feed.dart';
import 'package:another_iptv_player/ui/home/main_shell.dart';
import 'package:another_iptv_player/ui/home/my_list_tab.dart';
import 'package:another_iptv_player/ui/widgets/app_image.dart';
import 'package:another_iptv_player/ui/widgets/poster_card.dart';
import 'package:another_iptv_player/utils/app_themes.dart';
import 'package:another_iptv_player/controllers/playlist_controller.dart';
import 'package:another_iptv_player/l10n/app_localizations.dart';
import 'package:another_iptv_player/ui/profiles/add_profile_screen.dart';
import 'package:another_iptv_player/ui/profiles/profiles_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:another_iptv_player/services/custom_lists_service.dart';
import 'package:another_iptv_player/ui/lists/list_picker_sheet.dart';

const _imgDir = 'test/screenshots/images';
final Map<String, ui.Image> _images = {};

const _titles = [
  'Marée Haute',
  'Les Ombres du Nord',
  'Néon',
  'La Dernière Course',
  'Horizon',
  'Le Jardin Secret',
  'Sous la Glace',
  'Brûlant',
  'Altitude',
  'Minuit à Lisbonne',
  'Les Gardiens',
  'Cœur Sauvage',
  'Orbite',
  'La Promesse',
  'Vertige',
  'Écho',
];

const _channels = [
  'Info 24',
  'Sport+',
  'Ciné Max',
  'Kids',
  'Doc',
  'Musique',
  'Nature',
  'Cuisine',
];

String _poster(int i) => 'https://test/p${(i % 16).toString().padLeft(2, '0')}.jpg';
String _logo(int i) => 'https://test/c${(i % 8).toString().padLeft(2, '0')}.png';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/Inter-$w.otf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

Future<void> _loadImages() async {
  for (final f in Directory(_imgDir).listSync().whereType<File>()) {
    final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
    final frame = await codec.getNextFrame();
    _images['https://test/${f.uri.pathSegments.last}'] = frame.image;
  }
}

ContentItem _movie(int i) => ContentItem(
  'm$i',
  '|FR| ${_titles[i % 16]}',
  _poster(i),
  ContentType.vod,
  containerExtension: 'mkv',
  vodStream: VodStream(
    streamId: 'm$i',
    name: _titles[i % 16],
    streamIcon: _poster(i),
    categoryId: '1',
    rating: '8',
    rating5based: 4,
    containerExtension: 'mkv',
    createdAt: DateTime(2026),
    genre: 'Aventure, Drame',
  ),
);

ContentItem _series(int i) => ContentItem(
  's$i',
  _titles[i % 16],
  _poster(i),
  ContentType.series,
  seriesStream: SeriesStream(
    playlistId: 'demo',
    seriesId: 's$i',
    name: _titles[i % 16],
    cover: _poster(i),
    genre: 'Thriller',
    releaseDate: '2025-03-01',
  ),
);

ContentItem _channel(int i) => ContentItem(
  'l$i',
  _channels[i % 8],
  _logo(i),
  ContentType.liveStream,
  liveStream: LiveStream(
    streamId: 'l$i',
    name: _channels[i % 8],
    streamIcon: _logo(i),
    categoryId: '1',
    epgChannelId: '',
  ),
);

CategoryViewModel _cat(String name, List<ContentItem> items, CategoryType t) =>
    CategoryViewModel(
      category: Category(
        categoryId: name,
        categoryName: name,
        parentId: 0,
        playlistId: 'demo',
        type: t,
      ),
      contentItems: items,
    );

List<ContentItem> _range(ContentItem Function(int) f, int start, int n) => [
  for (var i = start; i < start + n; i++) f(i),
];

HomeFeedData _homeData() {
  final hero = ContentItem(
    'm4',
    'Horizon',
    'https://test/backdrop.jpg',
    ContentType.vod,
    containerExtension: 'mkv',
    vodStream: VodStream(
      streamId: 'm4',
      name: 'Horizon',
      streamIcon: 'https://test/backdrop.jpg',
      categoryId: '1',
      rating: '8',
      rating5based: 4,
      containerExtension: 'mkv',
      createdAt: DateTime(2026),
      genre: 'Science-fiction, Aventure',
    ),
  );
  WatchHistory h(int i, int watched, int total, ContentType t) => WatchHistory(
    playlistId: 'demo',
    contentType: t,
    streamId: 'h$i',
    watchDuration: Duration(minutes: watched),
    totalDuration: Duration(minutes: total),
    lastWatched: DateTime(2026),
    imagePath: _poster(i),
    title: t == ContentType.series ? '${_titles[i]} · S1 É3' : _titles[i],
  );
  return HomeFeedData(
    hero: hero,
    continueWatching: [
      h(9, 52, 118, ContentType.vod),
      h(1, 20, 45, ContentType.series),
      h(12, 80, 96, ContentType.vod),
    ],
    favorites: [
      for (final i in [5, 7, 13])
        Favorite(
          id: 'f$i',
          playlistId: 'demo',
          contentType: ContentType.vod,
          streamId: 'm$i',
          name: _titles[i],
          imagePath: _poster(i),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ],
    topMovies: _range(_movie, 0, 8),
    topSeries: _range(_series, 6, 8),
    movieCategories: [
      _cat('Nouveautés', _range(_movie, 3, 8), CategoryType.vod),
      _cat('Comédie', _range(_movie, 10, 8), CategoryType.vod),
    ],
    seriesCategories: [
      _cat('Séries policières', _range(_series, 2, 8), CategoryType.series),
    ],
  );
}

final _actions = HomeFeedActions(
  openItem: (_) {},
  playItem: (_) {},
  resume: (_) {},
  openFavorite: (_) {},
  openCategory: (_) {},
  toggleMyList: (_) {},
);

Widget _app(Brightness b, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('fr'),
  supportedLocales: const [Locale('fr'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppThemes.lightTheme,
  darkTheme: AppThemes.darkTheme,
  themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: home,
);

Widget _shell({required int index, required double topInset}) => MainShell(
  initialIndex: index,
  profileInitial: 'L',
  onSearch: () {},
  onProfile: () {},
  tabs: [
    ShellTab(
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      overlayTopBar: true,
      builder: (_) => HomeFeedView(
        data: _homeData(),
        actions: _actions,
        topInset: topInset,
      ),
    ),
    ShellTab(
      label: 'Films',
      icon: Icons.movie_outlined,
      selectedIcon: Icons.movie_rounded,
      builder: (_) => CatalogView(
        categories: [
          _cat('Nouveautés', _range(_movie, 0, 8), CategoryType.vod),
          _cat('Action', _range(_movie, 4, 8), CategoryType.vod),
          _cat('Comédie', _range(_movie, 8, 8), CategoryType.vod),
          _cat('Famille', _range(_movie, 12, 8), CategoryType.vod),
        ],
        onOpen: (_) {},
        onSeeAll: (_) {},
      ),
    ),
    ShellTab(
      label: 'Séries',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
      builder: (_) => const SizedBox(),
    ),
    ShellTab(
      label: 'TV',
      icon: Icons.live_tv_outlined,
      selectedIcon: Icons.live_tv_rounded,
      builder: (_) => CatalogView(
        shape: PosterShape.channel,
        categories: [
          _cat('Généralistes', _range(_channel, 0, 8), CategoryType.live),
          _cat('Sport', _range(_channel, 1, 8), CategoryType.live),
          _cat('Jeunesse', _range(_channel, 3, 8), CategoryType.live),
          _cat('Découverte', _range(_channel, 4, 8), CategoryType.live),
          _cat('Musique', _range(_channel, 5, 8), CategoryType.live),
        ],
        onOpen: (_) {},
        onSeeAll: (_) {},
      ),
    ),
    ShellTab(
      label: 'Ma liste',
      icon: Icons.bookmark_border_rounded,
      selectedIcon: Icons.bookmark_rounded,
      builder: (_) => MyListView(
        data: MyListData(
          favorites: [
            for (final i in [5, 7, 13, 2, 10, 15])
              Favorite(
                id: 'f$i',
                playlistId: 'demo',
                contentType: ContentType.vod,
                streamId: 'm$i',
                name: _titles[i],
                imagePath: _poster(i),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            for (final i in [0, 3, 5])
              Favorite(
                id: 'c$i',
                playlistId: 'demo',
                contentType: ContentType.liveStream,
                streamId: 'l$i',
                name: _channels[i],
                imagePath: _logo(i),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
          ],
          history: _homeData().continueWatching,
          customLists: _customLists,
        ),
        onOpenFavorite: (_) {},
        onRemoveFavorite: (_) {},
        onResume: (_) {},
        onRemoveHistory: (_) {},
        onRemoveFromList: (_, __) {},
        onCreateList: () {},
        onListMenu: (_) {},
      ),
    ),
  ],
);


final _customLists = [
  CustomList(
    id: 'noel',
    name: 'Films de Noël',
    items: [
      for (final i in [11, 4, 8, 14])
        Favorite(
          id: 'n$i',
          playlistId: 'demo',
          contentType: ContentType.vod,
          streamId: 'm$i',
          name: '|FR| ${_titles[i]}',
          imagePath: _poster(i),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ],
  ),
  const CustomList(id: 'famille', name: 'Soirée en famille', items: []),
];

Widget _movieDetail({bool withSheet = false}) {
  final detail = _movieDetailView();
  if (!withSheet) return detail;
  return Stack(
    children: [
      detail,
      const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
      Align(
        alignment: Alignment.bottomCenter,
        child: Builder(
          builder: (context) => Material(
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 24),
              child: ListPickerView(
                inMyList: true,
                lists: _customLists,
                itemId: 'm11',
                onToggleMyList: () {},
                onToggle: (_) {},
                onCreate: () {},
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _movieDetailView() => DetailView(
  title: '|FR| Minuit à Lisbonne (4K)',
  versions: const ['Standard', '4K', 'UHD'],
  selectedVersion: 1,
  onVersion: (_) {},
  posterUrl: _poster(9),
  backdropUrl: 'https://test/backdrop.jpg',
  rating: 7.4,
  meta: const ['2025', '1 h 58', 'Drame, Romance'],
  plot:
      'Une pianiste en tournée rate son dernier train et passe une nuit '
      'entière à traverser Lisbonne avec un inconnu. Au fil des rues, '
      'des souvenirs remontent et une décision s’impose avant l’aube.',
  credits: const [
    ('Réalisation', 'Inès Moreau'),
    ('Avec', 'Clara Diaz, Tomás Neves, Julie Arnaud'),
  ],
  playLabel: 'Reprendre',
  onPlay: () {},
  progress: 0.44,
  progressLabel: 'Reste 1 h 06',
  inList: true,
  onToggleList: () {},
  onTrailer: () {},
  related: MediaRow<ContentItem>(
    title: 'Dans la même catégorie',
    items: _range(_movie, 2, 8),
    itemBuilder: (context, item, width) => PosterCard(
      title: item.name,
      imageUrl: item.imagePath,
      width: width,
    ),
  ),
);

Widget _seriesDetail() => DetailView(
  title: 'Les Ombres du Nord',
  posterUrl: _poster(1),
  rating: 8.1,
  meta: const ['2024', '2 saisons', 'Policier'],
  plot:
      'Dans un village isolé du Grand Nord, une enquêtrice revient sur '
      'l’affaire qui a brisé sa carrière, dix ans plus tôt.',
  playLabel: 'Reprendre S1 É3',
  onPlay: () {},
  onToggleList: () {},
  onTrailer: () {},
  extra: EpisodesSection(
    initialSeason: 1,
    onTap: (_) {},
    episodes: [
      for (var i = 1; i <= 5; i++)
        EpisodeEntry(
          id: 'e$i',
          season: 1,
          number: i,
          title: ['Le retour', 'La cabane', 'Sous la neige', 'Le témoin', 'Aurore'][i - 1],
          imageUrl: _poster(i + 3),
          durationLabel: '${44 + i} min',
          plot: 'Clara retrouve une piste que tout le monde croyait perdue.',
          progress: i < 3 ? 1 : (i == 3 ? 0.45 : null),
        ),
      const EpisodeEntry(id: 'e21', season: 2, number: 1, title: 'Dégel'),
    ],
  ),
);

class _Device {
  final String name;
  final Size size;
  final double ratio;
  final double topPadding;

  const _Device(this.name, this.size, this.ratio, this.topPadding);
}

const _phone = _Device('phone', Size(393, 852), 3, 59);
const _tablet = _Device('tablet', Size(1180, 820), 2, 24);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    AppState.currentPlaylist = Playlist(
      id: 'demo',
      name: 'Léo',
      type: PlaylistType.xtream,
      url: 'http://demo',
      username: 'u',
      password: 'p',
      createdAt: DateTime(2026),
    );
    AppImage.debugBuilder = (context, url, fit, fallback) {
      final img = _images[url];
      if (img == null) return fallback(context);
      return RawImage(image: img, fit: fit, width: double.infinity, height: double.infinity);
    };
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    _Device d,
    Brightness b,
    Widget Function(double topInset) build,
  ) async {
    if (_images.isEmpty) await tester.runAsync(_loadImages);
    tester.view.physicalSize = d.size * d.ratio;
    tester.view.devicePixelRatio = d.ratio;
    tester.view.padding = FakeViewPadding(top: d.topPadding * d.ratio);
    tester.view.viewPadding = FakeViewPadding(top: d.topPadding * d.ratio);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(b, build(d.topPadding + 56)));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/${name}_${d.name}_${b.name}.png'),
    );
  }

  for (final b in Brightness.values) {
    testWidgets('accueil ${b.name}', (t) async {
      await shoot(t, 'accueil', _phone, b, (i) => _shell(index: 0, topInset: i));
    });
    testWidgets('films ${b.name}', (t) async {
      await shoot(t, 'films', _phone, b, (i) => _shell(index: 1, topInset: i));
    });
    testWidgets('maliste ${b.name}', (t) async {
      await shoot(t, 'maliste', _phone, b, (i) => _shell(index: 4, topInset: i));
    });
    testWidgets('tv ${b.name}', (t) async {
      await shoot(t, 'tv', _phone, b, (i) => _shell(index: 3, topInset: i));
    });
  }
  for (final b in Brightness.values) {
    testWidgets('film ${b.name}', (t) async {
      await shoot(t, 'film', _phone, b, (_) => _movieDetail());
    });
    testWidgets('serie ${b.name}', (t) async {
      await shoot(t, 'serie', _phone, b, (_) => _seriesDetail());
    });
  }
  for (final b in Brightness.values) {
    testWidgets('listes ${b.name}', (t) async {
      await shoot(t, 'listes', _phone, b, (_) => _movieDetail(withSheet: true));
    });
  }
  testWidgets('film tablette', (t) async {
    await shoot(t, 'film', _tablet, Brightness.dark, (_) => _movieDetail());
  });
  for (final b in Brightness.values) {
    testWidgets('profils ${b.name}', (t) async {
      await shoot(t, 'profils', _phone, b, (_) => ProfilesView(
        profiles: const [
          ProfileEntry(id: 'a', name: 'Léo', subtitle: 'Codes Xtream'),
          ProfileEntry(id: 'b', name: 'Maman', subtitle: 'Codes Xtream'),
          ProfileEntry(id: 'c', name: 'Papa', subtitle: 'Lien M3U'),
        ],
        onOpen: (_) {},
        onAdd: () {},
        onDelete: (_) {},
      ));
    });
    testWidgets('xtream ${b.name}', (t) async {
      await shoot(t, 'ajout_profil', _phone, b, (_) => ChangeNotifierProvider(
        create: (_) => PlaylistController(),
        child: const AddProfileScreen(),
      ));
    });
  }
  testWidgets('accueil tablette', (t) async {
    await shoot(t, 'accueil', _tablet, Brightness.dark, (i) => _shell(index: 0, topInset: i));
  });
}
