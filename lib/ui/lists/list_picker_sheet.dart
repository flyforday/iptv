import 'package:flutter/material.dart';

import '../../models/playlist_content_model.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/app_state.dart';
import '../../services/custom_lists_service.dart';
import '../../utils/app_themes.dart';

/// Demande un nom de liste (création ou renommage).
Future<String?> askListName(
  BuildContext context, {
  String initial = '',
  String title = 'Nouvelle liste',
  String action = 'Créer',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) {
      void submit() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.pop(dialog, name);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(hintText: 'Ex. Films de Noël'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Annuler'),
          ),
          FilledButton(onPressed: submit, child: Text(action)),
        ],
      );
    },
  );
}

/// Feuille « Ajouter à… » : Ma liste + les listes perso, cochables d'un
/// geste, et « Nouvelle liste » en bas.
Future<void> showListPicker(BuildContext context, ContentItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ListPicker(item: item),
  );
}

class _ListPicker extends StatefulWidget {
  final ContentItem item;

  const _ListPicker({required this.item});

  @override
  State<_ListPicker> createState() => _ListPickerState();
}

class _ListPickerState extends State<_ListPicker> {
  final _favorites = FavoritesRepository();
  final _lists = CustomListsService();
  bool? _inMyList;
  List<CustomList> _custom = [];

  String get _playlistId => AppState.currentPlaylist!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fav = await _favorites.isFavorite(
      widget.item.id,
      widget.item.contentType,
    );
    final lists = await _lists.load(_playlistId);
    if (!mounted) return;
    setState(() {
      _inMyList = fav;
      _custom = lists;
    });
  }

  Future<void> _toggleMyList() async {
    final added = await _favorites.toggleFavorite(widget.item);
    if (mounted) setState(() => _inMyList = added);
  }

  Future<void> _toggle(CustomList list) async {
    await _lists.toggle(_playlistId, list.id, widget.item);
    await _load();
  }

  Future<void> _create() async {
    final name = await askListName(context);
    if (name == null) return;
    final list = await _lists.create(_playlistId, name);
    await _lists.toggle(_playlistId, list.id, widget.item);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: _inMyList == null
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : ListPickerView(
                inMyList: _inMyList!,
                lists: _custom,
                itemId: widget.item.id,
                onToggleMyList: _toggleMyList,
                onToggle: _toggle,
                onCreate: _create,
              ),
      ),
    );
  }
}

/// Contenu visuel de la feuille « Ajouter à une liste ».
class ListPickerView extends StatelessWidget {
  final bool inMyList;
  final List<CustomList> lists;
  final String itemId;
  final VoidCallback onToggleMyList;
  final void Function(CustomList list) onToggle;
  final VoidCallback onCreate;

  const ListPickerView({
    super.key,
    required this.inMyList,
    required this.lists,
    required this.itemId,
    required this.onToggleMyList,
    required this.onToggle,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Ajouter à une liste',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _Row(
          icon: Icons.bookmark_rounded,
          label: 'Ma liste',
          checked: inMyList,
          onTap: onToggleMyList,
        ),
        for (final l in lists)
          _Row(
            icon: Icons.playlist_play_rounded,
            label: l.name,
            count: l.items.length,
            checked: l.contains(itemId),
            onTap: () => onToggle(l),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.add_rounded, color: AppColors.pink),
          title: const Text(
            'Nouvelle liste',
            style: TextStyle(
              color: AppColors.pink,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: onCreate,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool checked;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    required this.checked,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: count == null
          ? null
          : Text(
              count == 0
                  ? 'Vide'
                  : '$count titre${count! > 1 ? 's' : ''}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
      trailing: Icon(
        checked
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: checked ? AppColors.pink : theme.colorScheme.outline,
        size: 26,
      ),
      onTap: onTap,
    );
  }
}
