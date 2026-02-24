class AppConstants {
  // ── Firestore Collections ──────────────────────────────────
  static const String usersCollection = 'users';
  static const String notesCollection = 'notes';

  // ── Firebase Storage Paths ────────────────────────────────
  static const String audioStoragePath = 'recordings';
  static const String profileStoragePath = 'profiles';

  // ── OpenAI ────────────────────────────────────────────────
  static const String whisperModel = 'whisper-1';
  static const String gptModel = 'gpt-4o';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';

  // ── Whisper language codes ─────────────────────────────────
  static const Map<String, String> whisperLanguageCodes = {
    'en': 'en',
    'si': 'si',
    'ta': 'ta',
  };

  // ── Language display names ─────────────────────────────────
  static const Map<String, String> languageNames = {
    'en': 'English',
    'si': 'Sinhala',
    'ta': 'Tamil',
  };

  // ── Export formats ─────────────────────────────────────────
  static const String formatPdf = 'pdf';
  static const String formatDocx = 'docx';
  static const String formatTxt = 'txt';

  // ── SharedPreferences keys ─────────────────────────────────
  static const String prefSeenOnboarding = 'seen_onboarding';
  static const String prefRecordingLang = 'recording_language';

  // ── Limits ────────────────────────────────────────────────
  static const int maxKeywords = 8;
  static const int maxTitleWords = 8;
  static const int summaryMaxTokens = 600;
  static const int keywordMaxTokens = 200;
  static const int titleMaxTokens = 60;
}
