// lib/screens/note_detail/note_detail_screen.dart
// Displays structured BART summary with proper headings, keywords, key points

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../export/export_screen.dart';

const _bgTop = Color(0xFF6AABF8);
const _bgMid = Color(0xFF9AC8FB);
const _bgBot = Color(0xFFEFF5FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _cardBg = Color(0xFFFFFFFF);
const _border = Color(0xFFD0DFFF);

class NoteDetailScreen extends StatefulWidget {
  final NoteModel note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late NoteModel _note;
  bool _editing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _transcriptCtrl;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _tabCtrl = TabController(length: 3, vsync: this);
    _titleCtrl = TextEditingController(text: _note.title);
    _transcriptCtrl = TextEditingController(text: _note.transcript);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  void _toggleFavorite() async {
    final provider = context.read<NotesProvider>();
    await provider.toggleFavorite(_note.id);
    setState(() => _note = _note.copyWith(isFavorite: !_note.isFavorite));
  }

  void _saveEdits() async {
    final provider = context.read<NotesProvider>();
    final updated = _note.copyWith(
      title: _titleCtrl.text.trim(),
      transcription: _transcriptCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    await provider.updateNote(updated);
    setState(() {
      _note = updated;
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note updated', style: TextStyle(color: _textDark)),
          backgroundColor: _cardBg,
        ),
      );
    }
  }

  void _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete Note', style: TextStyle(color: _textDark)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: _textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<NotesProvider>().deleteNote(_note.id);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBot,
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SummaryTab(note: _note),
            _TranscriptTab(
              note: _note,
              editing: _editing,
              ctrl: _transcriptCtrl,
            ),
            _DetailsTab(note: _note),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _bgBot,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: _textDark),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _note.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _note.isFavorite ? const Color(0xFFFFD700) : _textGrey,
          ),
          onPressed: _toggleFavorite,
        ),
        if (_editing)
          IconButton(
            icon: const Icon(Icons.check_circle, color: _primary),
            onPressed: _saveEdits,
          )
        else
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _textGrey),
            onPressed: () => setState(() => _editing = true),
          ),
        PopupMenuButton<String>(
          color: _cardBg,
          icon: const Icon(Icons.more_vert, color: _textGrey),
          onSelected: (v) {
            if (v == 'delete') _deleteNote();
            if (v == 'export') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExportScreen(note: _note)),
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'export',
              child: Text('Export Note', style: TextStyle(color: _textDark)),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete Note',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        title: _editing
            ? TextField(
                controller: _titleCtrl,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              )
            : Text(
                _note.title,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
              ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgMid],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kTextTabBarHeight),
        child: Container(
          color: _cardBg,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: _primary,
            labelColor: _primary,
            unselectedLabelColor: _textGrey,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Transcript'),
              Tab(text: 'Details'),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//   SUMMARY TAB — Structured BART output with headings
// ════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final NoteModel note;
  const _SummaryTab({required this.note});

  @override
  Widget build(BuildContext context) {
    final summary = note.summary;
    if (summary.isEmpty) {
      return const Center(
        child: Text(
          'No summary available.',
          style: TextStyle(color: _textGrey),
        ),
      );
    }

    // Parse the markdown summary into sections
    final sections = _parseSummary(summary);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Category heading pill
        if (sections['heading'] != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sections['heading']!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Overview
        if (sections['overview'] != null) ...[
          _SectionHeader(icon: '📖', title: 'Overview'),
          const SizedBox(height: 8),
          _ContentCard(
            child: Text(
              sections['overview']!,
              style: const TextStyle(
                color: _textDark,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Key Points
        if (sections['key_points'] != null &&
            sections['key_points']!.isNotEmpty) ...[
          _SectionHeader(
            icon: '🔑',
            title: sections['points_label'] ?? 'Key Points',
          ),
          const SizedBox(height: 8),
          _ContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections['key_points']!
                  .split('\n')
                  .where((s) => s.trim().isNotEmpty)
                  .map(
                    (pt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              pt.replaceFirst(RegExp(r'^[•\-]\s*'), '').trim(),
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Keywords chips
        if (note.keywords.isNotEmpty) ...[
          _SectionHeader(icon: '🏷️', title: 'Topic Keywords'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: note.keywords
                .map(
                  (kw) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.15),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      kw,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Conclusion
        if (sections['conclusion'] != null) ...[
          _SectionHeader(icon: '💡', title: 'Conclusion'),
          const SizedBox(height: 8),
          _ContentCard(
            child: Text(
              sections['conclusion']!,
              style: const TextStyle(
                color: _textDark,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Word count footer
        Text(
          '${note.wordCount} words  •  ${_formatDate(note.createdAt)}',
          style: const TextStyle(color: _textGrey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, String?> _parseSummary(String summary) {
    final Map<String, String?> result = {};
    final lines = summary.split('\n');
    String? currentSection;
    final buffers = <String, StringBuffer>{};

    for (final line in lines) {
      if (line.startsWith('##')) {
        final heading = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        if (heading.contains('Overview')) {
          currentSection = 'overview';
        } else if (heading.contains('Concepts') ||
            heading.contains('Items') ||
            heading.contains('Points') ||
            heading.contains('Responses')) {
          currentSection = 'key_points';
          result['points_label'] = heading
              .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
              .trim();
        } else if (heading.contains('Conclusion')) {
          currentSection = 'conclusion';
        } else if (heading.contains('Keywords')) {
          currentSection = 'keywords_section';
        } else {
          currentSection = null;
        }
      } else if (line.contains('📚') ||
          line.contains('🗓️') ||
          line.contains('🎙️') ||
          line.contains('📝') ||
          line.contains('📄')) {
        result['heading'] = line.trim();
      } else if (currentSection != null && line.trim().isNotEmpty) {
        buffers.putIfAbsent(currentSection, StringBuffer.new);
        buffers[currentSection]!.writeln(line);
      }
    }

    for (final entry in buffers.entries) {
      result[entry.key] = entry.value.toString().trim();
    }
    return result;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════
//   TRANSCRIPT TAB
// ════════════════════════════════════════════════════════

class _TranscriptTab extends StatelessWidget {
  final NoteModel note;
  final bool editing;
  final TextEditingController ctrl;
  const _TranscriptTab({
    required this.note,
    required this.editing,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (editing)
          TextField(
            controller: ctrl,
            maxLines: null,
            style: const TextStyle(color: _textDark, fontSize: 15, height: 1.7),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              filled: true,
              fillColor: _cardBg,
            ),
          )
        else
          _ContentCard(
            child: Text(
              note.transcript.isEmpty
                  ? 'No transcript available.'
                  : note.transcript,
              style: const TextStyle(
                color: _textDark,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
//   DETAILS TAB
// ════════════════════════════════════════════════════════

class _DetailsTab extends StatelessWidget {
  final NoteModel note;
  const _DetailsTab({required this.note});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DetailRow('Category', note.category.label),
        _DetailRow('Language', note.language.toUpperCase()),
        _DetailRow('Word Count', '${note.wordCount} words'),
        _DetailRow('Created', _fmt(note.createdAt)),
        _DetailRow('Updated', _fmt(note.updatedAt)),
        _DetailRow('Favorite', note.isFavorite ? '⭐ Yes' : 'No'),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textGrey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String icon, title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Widget child;
  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}
