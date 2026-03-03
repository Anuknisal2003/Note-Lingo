import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/note_card.dart';

// ── Palette ────────────────────────────────────────────────────────
const _bgTop = Color(0xFF78B1F8);
const _bgMid = Color(0xFFAACDF9);
const _bgBot = Color(0xFFEEF4FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _border = Color(0xFFD0DFFF);

class NotesLibraryScreen extends StatefulWidget {
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
  String _sort = 'date';

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
        // search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A7CF5).withOpacity(0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              cursorColor: _primary,
              style: const TextStyle(
                fontSize: 14,
                color: _textDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search library…',
                hintStyle: TextStyle(
                  color: _textGrey.withOpacity(0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _primary.withOpacity(0.70),
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _textGrey.withOpacity(0.65),
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // filter chips
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

        // sort row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${notes.length} notes',
                style: TextStyle(
                  fontSize: 13,
                  color: _textGrey.withOpacity(0.85),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _sort = v),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: Row(
                  children: [
                    Icon(Icons.sort_rounded, size: 16, color: _textGrey),
                    const SizedBox(width: 4),
                    Text(
                      _sort == 'date'
                          ? 'Newest'
                          : _sort == 'name'
                          ? 'A–Z'
                          : 'Most words',
                      style: TextStyle(fontSize: 13, color: _textGrey),
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
      return Container(
        color: _bgBot,
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgMid, _bgBot],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.30, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // custom app bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _CircleBack(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      const Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String v, String label, IconData icon) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 18, color: _textDark),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: _textDark)),
          ],
        ),
      );
}

// ── Filter Chip ────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF6BAAF8), _deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _primary : _border),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _primary.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : _textGrey,
        ),
      ),
    ),
  );
}

// ── Empty state ────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final bool hasSearch;
  const _Empty({required this.hasSearch});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.folder_open_outlined,
              color: _textGrey,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'Nothing matches' : 'Library is empty',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try adjusting filters or search term'
                : 'Record your first note to see it here',
            style: TextStyle(fontSize: 14, color: _textGrey.withOpacity(0.85)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ── Circle back button ─────────────────────────────────────────────

class _CircleBack extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBack({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        shape: BoxShape.circle,
        border: Border.all(color: _border, width: 1.2),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 16,
        color: _textDark,
      ),
    ),
  );
}
