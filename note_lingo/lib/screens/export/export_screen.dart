import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';

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

  final _formats = const [
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
          content: Text('Exported as ${formatId.toUpperCase()} ✓'),
          backgroundColor: AppColors.bgSurface,
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
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Export Note'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
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
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.note.wordCount} words · ${widget.note.category.label}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Include in Export',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),

            _ToggleTile(
              label: '🤖  AI Summary',
              value: _includeSummary,
              onChanged: (v) => setState(() => _includeSummary = v),
            ),
            _ToggleTile(
              label: '🎙️  Full Transcript',
              value: _includeTranscript,
              onChanged: (v) => setState(() => _includeTranscript = v),
            ),
            _ToggleTile(
              label: '#  Keywords',
              value: _includeKeywords,
              onChanged: (v) => setState(() => _includeKeywords = v),
            ),
            _ToggleTile(
              label: '📋  Note Metadata',
              value: _includeMeta,
              onChanged: (v) => setState(() => _includeMeta = v),
            ),
            const SizedBox(height: 28),

            Text(
              'Export Format',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),

            ..._formats.map(
              (fmt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FormatCard(
                  format: fmt,
                  exporting: _exporting == fmt.id,
                  disabled: _exporting != null && _exporting != fmt.id,
                  onTap: () => _export(fmt.id),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Toggle Tile ───────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Format Card ───────────────────────────────────────────────────

class _Format {
  final String id;
  final String label;
  final String desc;
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
  final bool exporting;
  final bool disabled;
  final VoidCallback onTap;
  const _FormatCard({
    required this.format,
    required this.exporting,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bgBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: format.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: format.glow.withOpacity(0.3),
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      format.desc,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download_rounded,
                color: exporting ? AppColors.textMuted : AppColors.primaryLight,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
