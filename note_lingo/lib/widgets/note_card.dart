import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/note_model.dart';
import '../screens/note_detail/note_detail_screen.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  const NoteCard({super.key, required this.note});

  Color _catColor() {
    switch (note.category) {
      case NoteCategory.lecture:
        return const Color(0xFF6C63FF);
      case NoteCategory.meeting:
        return const Color(0xFF00B4D8);
      case NoteCategory.interview:
        return const Color(0xFF00D9B5);
      case NoteCategory.personal:
        return const Color(0xFFFFB547);
      case NoteCategory.other:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${note.category.emoji} ${note.category.label}',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  note.languageLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (note.isFavorite) ...[
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _relativeDate(note.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              note.title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Preview
            Text(
              note.previewText,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Keywords
            if (note.keywords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: note.keywords.take(3).map((k) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$k',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),

            // Bottom meta row
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: AppColors.textMuted,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  note.formattedDuration,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.text_fields_rounded,
                  color: AppColors.textMuted,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${note.wordCount}w',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
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
    return '${m[dt.month - 1]} ${dt.day}';
  }
}
