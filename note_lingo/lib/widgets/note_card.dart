import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../screens/note_detail/note_detail_screen.dart';

const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _cardBg = Color(0xFFFFFFFF);
const _border = Color(0xFFD0DFFF);
const _primary = Color(0xFF4F8EF7);

class NoteCard extends StatelessWidget {
  final NoteModel note;
  const NoteCard({super.key, required this.note});

  Color _catColor() {
    switch (note.category) {
      case NoteCategory.lecture:
        return const Color(0xFF3F7DF0);
      case NoteCategory.meeting:
        return const Color(0xFF2E9BDB);
      case NoteCategory.interview:
        return const Color(0xFF2BAAA0);
      case NoteCategory.personal:
        return const Color(0xFFF59E0B);
      case NoteCategory.other:
        return const Color(0xFF6B7A99);
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
          color: _cardBg.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textGrey.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                if (note.isFavorite) ...[
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _relativeDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textGrey.withOpacity(0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              note.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Preview
            Text(
              note.previewText,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _textGrey.withOpacity(0.95),
                fontWeight: FontWeight.w500,
              ),
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
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(
                      '#$k',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),

            // Bottom meta row
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: _textGrey, size: 12),
                const SizedBox(width: 4),
                Text(
                  note.formattedDuration,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textGrey,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.text_fields_rounded,
                  color: _textGrey,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${note.wordCount}w',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textGrey,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _textGrey,
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
