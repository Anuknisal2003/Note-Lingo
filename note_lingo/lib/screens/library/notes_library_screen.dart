import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/note_card.dart';

class NotesLibraryScreen extends StatefulWidget {
  /// When [embedded] is true, appBar leading is hidden (used inside HomeScreen tabs)
  final bool embedded;
  const NotesLibraryScreen({super.key, this.embedded = false});

  @override
  State<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends State<NotesLibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  NoteCategory? _filterCat;
  bool _favOnly = false;
  String _sort = 'date'; // date | name | words

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<NoteModel> _filtered(List<NoteModel> all) {
    var list = all.toList();
    if (_favOnly) list = list.where((n) => n.isFavorite).toList();
    if (_filterCat != null)
      list = list.where((n) => n.category == _filterCat).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (n) =>
                n.title.toLowerCase().contains(q) ||
                n.summary.toLowerCase().contains(q) ||
                n.keywords.any((k) => k.toLowerCase().contains(q)),
          )
          .toList();
    }
    if (_sort == 'date')
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_sort == 'name') list.sort((a, b) => a.title.compareTo(b.title));
    if (_sort == 'words')
      list.sort((a, b) => b.wordCount.compareTo(a.wordCount));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<NotesProvider>().notes;
    final notes = _filtered(all);

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search library...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                label: '⭐ Starred',
                active: _favOnly,
                onTap: () => setState(() => _favOnly = !_favOnly),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: '🗂️ All',
                active: _filterCat == null,
                onTap: () => setState(() => _filterCat = null),
              ),
              const SizedBox(width: 8),
              ...NoteCategory.values
                  .where((c) => c != NoteCategory.other)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: '${c.emoji} ${c.label}',
                        active: _filterCat == c,
                        onTap: () => setState(() => _filterCat = c),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${notes.length} notes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _sort = v),
                icon: Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sort == 'date'
                          ? 'Newest'
                          : _sort == 'name'
                          ? 'A–Z'
                          : 'Most words',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                itemBuilder: (_) => [
                  _menuItem('date', 'Newest First', Icons.schedule_rounded),
                  _menuItem('name', 'Name A–Z', Icons.sort_by_alpha_rounded),
                  _menuItem('words', 'Most Words', Icons.text_fields_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: notes.isEmpty
              ? _Empty(
                  hasSearch:
                      _search.isNotEmpty || _favOnly || _filterCat != null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NoteCard(note: notes[i]),
                  ),
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Library'),
      ),
      body: body,
    );
  }

  PopupMenuItem<String> _menuItem(String v, String label, IconData icon) {
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.bgBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasSearch;
  const _Empty({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.folder_open_outlined,
              color: AppColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'Nothing matches' : 'Library is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try adjusting filters or search term'
                  : 'Record your first note to see it here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
