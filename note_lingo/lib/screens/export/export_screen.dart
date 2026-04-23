import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';

// ── Palette ────────────────────────────────────────────────────────
const _bgTop = Color(0xFF6AABF8);
const _bgMid = Color(0xFF9AC8FB);
const _bgBot = Color(0xFFEFF5FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _cardBg = Color(0xFFFFFFFF);
const _border = Color(0xFFD0DFFF);

class ExportScreen extends StatefulWidget {
  final NoteModel note;
  const ExportScreen({super.key, required this.note});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _includeSummary = true;
  bool _includeTranscript = true;
  bool _includeKeywords = true;
  bool _includeMeta = true;
  String? _exporting;

  static const _formats = [
    _Format(
      id: 'pdf',
      label: 'PDF',
      desc: 'Best for sharing & printing',
      icon: Icons.picture_as_pdf_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFFFF5370), Color(0xFFFF8A65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: Color(0xFFFF5370),
    ),
    _Format(
      id: 'docx',
      label: 'DOCX',
      desc: 'Editable Word document',
      icon: Icons.article_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: Color(0xFF2979FF),
    ),
    _Format(
      id: 'txt',
      label: 'TXT',
      desc: 'Plain text — universal format',
      icon: Icons.text_snippet_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFF00D9B5), Color(0xFF0099CC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: Color(0xFF00D9B5),
    ),
  ];

  Future<void> _export(String formatId) async {
    if (!(_includeSummary || _includeTranscript || _includeKeywords || _includeMeta)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one section to export.')),
      );
      return;
    }

    setState(() => _exporting = formatId);
    try {
      await context.read<NotesProvider>().exportNote(
        widget.note,
        format: formatId,
        includeSummary: _includeSummary,
        includeTranscript: _includeTranscript,
        includeKeywords: _includeKeywords,
        includeMeta: _includeMeta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported as ${formatId.toUpperCase()}',
            style: const TextStyle(color: _textDark),
          ),
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // gradient background
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
                        'Export Note',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // note preview card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardBg.withOpacity(0.80),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A7CF5,
                                ).withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6BAAF8), _deep],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primary.withOpacity(0.28),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.note_alt_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.note.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.note.wordCount} words · ${widget.note.category.label}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textGrey.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        const _SectionLabel(text: 'Include in Export'),
                        const SizedBox(height: 12),

                        _ToggleTile(
                          label: 'AI Summary',
                          value: _includeSummary,
                          onChanged: (v) => setState(() => _includeSummary = v),
                        ),
                        _ToggleTile(
                          label: 'Full Transcript',
                          value: _includeTranscript,
                          onChanged: (v) =>
                              setState(() => _includeTranscript = v),
                        ),
                        _ToggleTile(
                          label: 'Keywords',
                          value: _includeKeywords,
                          onChanged: (v) =>
                              setState(() => _includeKeywords = v),
                        ),
                        _ToggleTile(
                          label: 'Note Metadata',
                          value: _includeMeta,
                          onChanged: (v) => setState(() => _includeMeta = v),
                        ),

                        const SizedBox(height: 28),
                        const _SectionLabel(text: 'Export Format'),
                        const SizedBox(height: 12),

                        ..._formats.map(
                          (fmt) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FormatCard(
                              format: fmt,
                              exporting: _exporting == fmt.id,
                              disabled:
                                  _exporting != null && _exporting != fmt.id,
                              onTap: () => _export(fmt.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: _textDark,
      letterSpacing: -0.2,
    ),
  );
}

// ── Toggle Tile ────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: _cardBg.withOpacity(0.72),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: value ? _primary.withOpacity(0.40) : _border),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4A7CF5).withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _primary,
          activeTrackColor: _primary.withOpacity(0.30),
        ),
      ],
    ),
  );
}

// ── Format Card ────────────────────────────────────────────────────

class _Format {
  final String id, label, desc;
  final IconData icon;
  final LinearGradient gradient;
  final Color glow;
  const _Format({
    required this.id,
    required this.label,
    required this.desc,
    required this.icon,
    required this.gradient,
    required this.glow,
  });
}

class _FormatCard extends StatelessWidget {
  final _Format format;
  final bool exporting, disabled;
  final VoidCallback onTap;
  const _FormatCard({
    required this.format,
    required this.exporting,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: AnimatedOpacity(
      opacity: disabled ? 0.40 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg.withOpacity(0.80),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A7CF5).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: format.gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: format.glow.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: exporting
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Icon(format.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    format.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textGrey.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              color: exporting ? _textGrey : _primary,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Circle back ────────────────────────────────────────────────────

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
