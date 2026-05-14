import 'package:flutter_test/flutter_test.dart';
import 'package:note_lingo/models/note_model.dart';

void main() {
  group('NoteModel', () {
    test('fields are set correctly on construction', () {
      final now = DateTime(2026, 1, 1);
      final note = NoteModel(
        id: 'test-id',
        userId: 'user-1',
        title: 'Test Note',
        transcription: 'Hello world',
        summary: 'A summary',
        language: 'en',
        category: NoteCategory.personal,
        keywords: ['hello', 'world'],
        wordCount: 2,
        duration: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(note.id, 'test-id');
      expect(note.title, 'Test Note');
      expect(note.language, 'en');
      expect(note.keywords, ['hello', 'world']);
      expect(note.isFavorite, false);
      expect(note.category, NoteCategory.personal);
    });

    test('copyWith updates fields without changing others', () {
      final now = DateTime(2026, 1, 1);
      final note = NoteModel(
        id: 'id',
        userId: 'user',
        title: 'Original',
        transcription: '',
        summary: '',
        language: 'en',
        category: NoteCategory.other,
        keywords: const [],
        wordCount: 0,
        duration: 0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = note.copyWith(title: 'Updated', isFavorite: true);
      expect(updated.title, 'Updated');
      expect(updated.isFavorite, true);
      expect(updated.id, 'id');
      expect(updated.language, 'en');
    });

    test('NoteCategory has correct labels', () {
      expect(NoteCategory.lecture.label, 'Lecture');
      expect(NoteCategory.meeting.label, 'Meeting');
      expect(NoteCategory.interview.label, 'Interview');
      expect(NoteCategory.personal.label, 'Personal');
      expect(NoteCategory.other.label, 'Other');
    });

    test('formattedDuration formats correctly', () {
      final now = DateTime(2026, 1, 1);
      final note = NoteModel(
        id: 'id',
        userId: 'user',
        title: 'T',
        transcription: '',
        summary: '',
        language: 'en',
        category: NoteCategory.other,
        keywords: const [],
        wordCount: 0,
        duration: 125,
        createdAt: now,
        updatedAt: now,
      );
      expect(note.formattedDuration, '02:05');
    });
  });
}
