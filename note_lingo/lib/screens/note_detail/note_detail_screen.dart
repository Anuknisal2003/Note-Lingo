import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../export/export_screen.dart';

// ── Palette ────────────────────────────────────────────────────────
const _bgTop = Color(0xFF6AABF8);
const _bgMid = Color(0xFF9AC8FB);
const _bgBot = Color(0xFFEFF5FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _cardBg = Color(0xFFFFFFFF);
const _inputBg = Color(0xFFF0F5FF);
const _border = Color(0xFFD0DFFF);
const _error = Color(0xFFE53E3E);
const _warning = Color(0xFFF59E0B);
const _success = Color(0xFF10B981);
const _accent = Color(0xFF7C3AED);

class NoteDetailScreen extends StatefulWidget {
  final NoteModel note;
  final bool isNew;
  const NoteDetailScreen({super.key, required this.note, this.isNew = false});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _transcriptCtrl;
  bool _editing = false;
  bool _saving = false;
  late NoteModel _note;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _tabCtrl = TabController(length: 3, vsync: this);
    _titleCtrl = TextEditingController(text: _note.title);
    _summaryCtrl = TextEditingController(text: _note.summary);
    _transcriptCtrl = TextEditingController(text: _note.transcription);
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotesProvider>().addNote(_note);
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    setState(() => _saving = true);
    final updated = _note.copyWith(
      title: _titleCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      transcription: _transcriptCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    await context.read<NotesProvider>().updateNote(updated);
    setState(() {
      _note = updated;
      _saving = false;
      _editing = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note saved ✓'),
        backgroundColor: _cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final updated = _note.copyWith(isFavorite: !_note.isFavorite);
    await context.read<NotesProvider>().updateNote(updated);
    setState(() => _note = updated);
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Note',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: _textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textGrey)),
          ),
          TextButton(
            onPressed: () async {
              await context.read<NotesProvider>().deleteNote(_note.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBot,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          // ── Sliver App Bar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: _bgTop,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textDark,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _note.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _note.isFavorite ? _warning : _textGrey,
                ),
                onPressed: _toggleFavorite,
              ),
              if (_editing)
                IconButton(
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _success,
                          ),
                        )
                      : const Icon(Icons.check_rounded, color: _success),
                  onPressed: _saving ? null : _saveEdits,
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: _textDark),
                  onPressed: () => setState(() => _editing = true),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: _textDark),
                color: _cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (v) {
                  if (v == 'export') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(note: _note),
                      ),
                    );
                  } else if (v == 'delete') {
                    _deleteNote();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 18,
                          color: _textDark,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Export',
                          style: TextStyle(color: _textDark),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: _error,
                        ),
                        const SizedBox(width: 10),
                        const Text('Delete', style: TextStyle(color: _error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_bgTop, _bgMid],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _Badge(
                              text:
                                  '${_note.category.emoji} ${_note.category.label}',
                              color: _primary,
                            ),
                            _Badge(
                              text:
                                  '${_note.languageFlag} ${_note.languageLabel}',
                              color: _accent,
                            ),
                            if (_note.isFavorite)
                              _Badge(text: '⭐ Starred', color: _warning),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _editing
                            ? TextField(
                                controller: _titleCtrl,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              )
                            : Text(
                                _note.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fmtDate(_note.createdAt)} · ${_note.wordCount} words · ${_note.formattedDuration}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textGrey.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // keywords
          if (_note.keywords.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _note.keywords
                      .map((k) => _KeywordChip(keyword: k))
                      .toList(),
                ),
              ),
            ),

          // tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: _primary,
                unselectedLabelColor: _textGrey,
                indicatorColor: _primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Transcript'),
                  Tab(text: 'Details'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _TextTab(
              ctrl: _summaryCtrl,
              editing: _editing,
              icon: Icons.auto_awesome_rounded,
              color: _accent,
              badge: 'AI Summary',
              emptyMsg: 'No summary generated.',
            ),
            _TextTab(
              ctrl: _transcriptCtrl,
              editing: _editing,
              icon: Icons.mic_rounded,
              color: _primary,
              badge: 'Full Transcript',
              emptyMsg: 'No transcript available.',
            ),
            _DetailsTab(
              note: _note,
              onExport: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExportScreen(note: _note)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Text Tab ───────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  final TextEditingController ctrl;
  final bool editing;
  final IconData icon;
  final Color color;
  final String badge, emptyMsg;

  const _TextTab({
    required this.ctrl,
    required this.editing,
    required this.icon,
    required this.color,
    required this.badge,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    physics: const BouncingScrollPhysics(),
    child: editing
        ? TextField(
            controller: ctrl,
            maxLines: null,
            style: const TextStyle(fontSize: 15, color: _textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: _inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          )
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg.withOpacity(0.80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A7CF5).withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: _border),
                const SizedBox(height: 12),
                Text(
                  ctrl.text.isEmpty ? emptyMsg : ctrl.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: ctrl.text.isEmpty ? _textGrey : _textDark,
                    fontStyle: ctrl.text.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
  );
}

// ── Details Tab ────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onExport;
  const _DetailsTab({required this.note, required this.onExport});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        _DetailRow(Icons.label_outline, 'Category', note.category.label),
        _DetailRow(Icons.language_rounded, 'Language', note.languageLabel),
        _DetailRow(
          Icons.text_fields_rounded,
          'Word Count',
          '${note.wordCount}',
        ),
        _DetailRow(Icons.timer_outlined, 'Duration', note.formattedDuration),
        _DetailRow(
          Icons.calendar_today_outlined,
          'Created',
          _fmtFull(note.createdAt),
        ),
        _DetailRow(Icons.update_rounded, 'Updated', _fmtFull(note.updatedAt)),
        if (note.audioUrl != null)
          _DetailRow(Icons.audio_file_outlined, 'Audio', 'Stored in cloud'),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onExport,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6BAAF8), _deep],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_outlined, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Export This Note',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String _fmtFull(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$min';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 17),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: _textGrey.withOpacity(0.90)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Shared small widgets ───────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.55),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.40)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _KeywordChip extends StatelessWidget {
  final String keyword;
  const _KeywordChip({required this.keyword});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Text(
      '#$keyword',
      style: const TextStyle(fontSize: 11, color: _textGrey),
    ),
  );
}
