import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/favorite.dart';
import '../models/playlist_content_model.dart';

/// Une liste créée par l'utilisateur, par exemple « Films de Noël ».
class CustomList {
  final String id;
  final String name;
  final List<Favorite> items;

  const CustomList({required this.id, required this.name, required this.items});

  bool contains(String streamId) => items.any((f) => f.streamId == streamId);

  CustomList copyWith({String? name, List<Favorite>? items}) => CustomList(
    id: id,
    name: name ?? this.name,
    items: items ?? this.items,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': [for (final f in items) f.toJson()],
  };

  factory CustomList.fromJson(Map<String, dynamic> json) => CustomList(
    id: json['id'] as String,
    name: json['name'] as String,
    items: [
      for (final f in (json['items'] as List? ?? const []))
        Favorite.fromJson(Map<String, dynamic>.from(f as Map)),
    ],
  );
}

/// Listes personnelles d'un profil, gardées sur le téléphone.
/// « Ma liste » reste la liste par défaut (favoris) ; celles-ci s'y ajoutent.
class CustomListsService {
  static const _uuid = Uuid();

  static String _key(String playlistId) => 'custom_lists_$playlistId';

  Future<List<CustomList>> load(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(playlistId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List;
      return [
        for (final l in data)
          CustomList.fromJson(Map<String, dynamic>.from(l as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(String playlistId, List<CustomList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(playlistId),
      jsonEncode([for (final l in lists) l.toJson()]),
    );
  }

  Future<bool> containsAnywhere(String playlistId, String streamId) async {
    final lists = await load(playlistId);
    return lists.any((l) => l.contains(streamId));
  }

  Future<CustomList> create(String playlistId, String name) async {
    final lists = await load(playlistId);
    final list = CustomList(id: _uuid.v4(), name: name.trim(), items: []);
    await _save(playlistId, [...lists, list]);
    return list;
  }

  Future<void> rename(String playlistId, String listId, String name) async {
    final lists = await load(playlistId);
    await _save(playlistId, [
      for (final l in lists) l.id == listId ? l.copyWith(name: name.trim()) : l,
    ]);
  }

  Future<void> delete(String playlistId, String listId) async {
    final lists = await load(playlistId);
    await _save(playlistId, lists.where((l) => l.id != listId).toList());
  }

  /// Ajoute l'élément s'il n'y est pas, le retire sinon. Renvoie true s'il
  /// est maintenant dans la liste.
  Future<bool> toggle(
    String playlistId,
    String listId,
    ContentItem item,
  ) async {
    final lists = await load(playlistId);
    var added = false;
    final updated = [
      for (final l in lists)
        if (l.id != listId)
          l
        else if (l.contains(item.id))
          l.copyWith(
            items: l.items.where((f) => f.streamId != item.id).toList(),
          )
        else ...[
          () {
            added = true;
            final now = DateTime.now();
            return l.copyWith(
              items: [
                Favorite(
                  id: _uuid.v4(),
                  playlistId: playlistId,
                  contentType: item.contentType,
                  streamId: item.id,
                  m3uItemId: item.m3uItem?.id,
                  name: item.name,
                  imagePath: item.imagePath,
                  createdAt: now,
                  updatedAt: now,
                ),
                ...l.items,
              ],
            );
          }(),
        ],
    ];
    await _save(playlistId, updated);
    return added;
  }

  Future<void> remove(String playlistId, String listId, String streamId) async {
    final lists = await load(playlistId);
    await _save(playlistId, [
      for (final l in lists)
        l.id == listId
            ? l.copyWith(
                items: l.items.where((f) => f.streamId != streamId).toList(),
              )
            : l,
    ]);
  }
}
