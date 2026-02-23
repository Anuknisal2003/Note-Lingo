import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../export/export_screen.dart';

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

    // If this is a new note, save it to Firestore
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note saved ✓')));
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
        title: const Text('Delete Note'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<NotesProvider>().deleteNote(_note.id);
              if (!mounted) return;
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          // ── Sliver App Bar ───────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _note.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _note.isFavorite
                      ? AppColors.warning
                      : AppColors.textMuted,
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
                            color: AppColors.success,
                          ),
                        )
                      : const Icon(
                          Icons.check_rounded,
                          color: AppColors.success,
                        ),
                  onPressed: _saving ? null : _saveEdits,
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => setState(() => _editing = true),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
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
                        const Icon(
                          Icons.download_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Export',
                          style: Theme.of(context).textTheme.bodyLarge,
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
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.25),
                      Colors.transparent,
                    ],
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
                        // Badges
                        Wrap(
                          spacing: 8,
                          children: [
                            _Badge(
                              text:
                                  '${_note.category.emoji} ${_note.category.label}',
                              color: AppColors.primary,
                            ),
                            _Badge(
                              text:
                                  '${_note.languageFlag} ${_note.languageLabel}',
                              color: AppColors.accent,
                            ),
                            if (_note.isFavorite)
                              _Badge(
                                text: '⭐ Starred',
                                color: AppColors.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Title
                        _editing
                            ? TextField(
                                controller: _titleCtrl,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              )
                            : Text(
                                _note.title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fmtDate(_note.createdAt)} · ${_note.wordCount} words · ${_note.formattedDuration}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Keywords ─────────────────────────────────────
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

          // ── Tabs ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TabBar(
                controller: _tabCtrl,
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
              color: AppColors.accent,
              badge: 'AI Summary',
              emptyMsg: 'No summary generated.',
            ),
            _TextTab(
              ctrl: _transcriptCtrl,
              editing: _editing,
              icon: Icons.mic_rounded,
              color: AppColors.primaryLight,
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

// ── Text Tab ──────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  final TextEditingController ctrl;
  final bool editing;
  final IconData icon;
  final Color color;
  final String badge;
  final String emptyMsg;

  const _TextTab({
    required this.ctrl,
    required this.editing,
    required this.icon,
    required this.color,
    required this.badge,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: editing
          ? TextField(
              controller: ctrl,
              maxLines: null,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgBorder),
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
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    ctrl.text.isEmpty ? emptyMsg : ctrl.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ctrl.text.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
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
}

// ── Details Tab ───────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onExport;
  const _DetailsTab({required this.note, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export This Note'),
            ),
          ),
        ],
      ),
    );
  }

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
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final String keyword;
  const _KeywordChip({required this.keyword});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Text(
        '#$keyword',
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
