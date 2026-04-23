import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../providers/recording_provider.dart';
import '../../providers/language_provider.dart';
import '../note_detail/note_detail_screen.dart';

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
const _error = Color(0xFFE53E3E);
const _warning = Color(0xFFF59E0B);

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _pulseAnim;
  NoteCategory _category = NoteCategory.lecture;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStop(RecordingProvider rp, String language) async {
    await rp.stopRecording(category: _category, language: language);
    if (!mounted) return;

    if (rp.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: _error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rp.error!,
                  style: const TextStyle(color: _textDark),
                ),
              ),
            ],
          ),
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      rp.clearError();
      return;
    }

    if (rp.processedNote != null) {
      final note = rp.processedNote!;
      await context.read<NotesProvider>().loadNotes();
      rp.clearProcessed();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
      );
    }
  }

  Future<bool> _confirmDiscard(RecordingProvider rp) async {
    if (!rp.isRecording && !rp.isPaused) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Discard Recording?',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your current recording will be lost. This cannot be undone.',
          style: TextStyle(color: _textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Recording',
              style: TextStyle(color: _primary),
            ),
          ),
          TextButton(
            onPressed: () {
              rp.cancelRecording();
              Navigator.pop(context, true);
            },
            child: const Text('Discard', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RecordingProvider>();
    final lang = context.watch<LanguageProvider>();

    return PopScope(
      canPop: !rp.isRecording && !rp.isPaused,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await _confirmDiscard(rp);
          if (ok && mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bgTop, _bgMid, _bgBot],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Custom app bar ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _textDark,
                          ),
                          onPressed: () async {
                            final ok = await _confirmDiscard(rp);
                            if (ok && mounted) Navigator.pop(context);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'New Recording',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ),
                        _LanguagePill(
                          value: lang.selectedLanguage,
                          onChanged: (v) => lang.setLanguage(v),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // visualizer
                          _RecordVisualizer(
                            isRecording: rp.isRecording,
                            isPaused: rp.isPaused,
                            isProcessing: rp.isProcessing,
                            pulseAnim: _pulseAnim,
                          ),
                          const SizedBox(height: 24),

                          // timer
                          Text(
                            rp.formattedTime,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // status
                          _StatusLabel(
                            isRecording: rp.isRecording,
                            isPaused: rp.isPaused,
                            isProcessing: rp.isProcessing,
                            processingStatus: rp.processingStatus,
                          ),

                          // upload progress
                          if (rp.isProcessing &&
                              rp.uploadProgress > 0 &&
                              rp.uploadProgress < 1) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rp.uploadProgress,
                                backgroundColor: _border,
                                color: _primary,
                                minHeight: 3,
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // category selector
                          if (!rp.isRecording &&
                              !rp.isPaused &&
                              !rp.isProcessing) ...[
                            _CategorySelector(
                              selected: _category,
                              onChanged: (c) => setState(() => _category = c),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // live transcript
                          if (rp.liveTranscript.isNotEmpty ||
                              rp.isRecording) ...[
                            _LiveTranscript(text: rp.liveTranscript),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // controls
                  _Controls(
                    isRecording: rp.isRecording,
                    isPaused: rp.isPaused,
                    isProcessing: rp.isProcessing,
                    onStart: () => rp.startRecording(),
                    onPause: () => rp.pauseRecording(),
                    onResume: () => rp.resumeRecording(),
                    onStop: () => _onStop(rp, lang.selectedLanguage),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visualizer ────────────────────────────────────────────────────

class _RecordVisualizer extends StatelessWidget {
  final bool isRecording, isPaused, isProcessing;
  final Animation<double> pulseAnim;

  const _RecordVisualizer({
    required this.isRecording,
    required this.isPaused,
    required this.isProcessing,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    height: 200,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (isRecording && !isPaused) ...[
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 160 + pulseAnim.value * 36,
              height: 160 + pulseAnim.value * 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _error.withOpacity(0.22 * (1 - pulseAnim.value)),
                  width: 2,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 130 + pulseAnim.value * 20,
              height: 130 + pulseAnim.value * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _error.withOpacity(0.05 + pulseAnim.value * 0.04),
              ),
            ),
          ),
        ],
        if (isProcessing)
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              color: _primary.withOpacity(0.30),
              strokeWidth: 2,
            ),
          ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: isRecording
                ? const LinearGradient(
                    colors: [Color(0xFFFF5370), Color(0xFFFF2D55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF6BAAF8), _deep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isRecording ? _error : _primary).withOpacity(0.38),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            isProcessing
                ? Icons.auto_awesome_rounded
                : isRecording
                ? (isPaused ? Icons.pause_rounded : Icons.mic_rounded)
                : Icons.mic_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ],
    ),
  );
}

// ── Status Label ──────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  final bool isRecording, isPaused, isProcessing;
  final String processingStatus;

  const _StatusLabel({
    required this.isRecording,
    required this.isPaused,
    required this.isProcessing,
    required this.processingStatus,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (isProcessing) {
      label = processingStatus.isNotEmpty ? processingStatus : 'Processing…';
      color = _primary;
    } else if (isPaused) {
      label = '⏸  Paused — tap Resume to continue';
      color = _warning;
    } else if (isRecording) {
      label = '● Recording — speak clearly';
      color = _error;
    } else {
      label = 'Tap Start to begin recording';
      color = _textGrey;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        label,
        key: ValueKey(label),
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Category Selector ─────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final NoteCategory selected;
  final ValueChanged<NoteCategory> onChanged;
  const _CategorySelector({required this.selected, required this.onChanged});

  static const _cats = [
    (NoteCategory.lecture, '🎓', 'Lecture'),
    (NoteCategory.meeting, '💼', 'Meeting'),
    (NoteCategory.interview, '🤝', 'Interview'),
    (NoteCategory.personal, '📔', 'Personal'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Note Category',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (cat, emoji, label) = _cats[i];
            final active = selected == cat;
            return GestureDetector(
              onTap: () => onChanged(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [Color(0xFF6BAAF8), _deep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: active ? null : _cardBg.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: active ? _primary : _border),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _primary.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : _textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

// ── Live Transcript ───────────────────────────────────────────────

class _LiveTranscript extends StatelessWidget {
  final String text;
  const _LiveTranscript({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxHeight: 160),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Live Transcript',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              text.isEmpty ? 'Listening…' : text,
              style: TextStyle(
                fontSize: 14,
                color: text.isEmpty ? _textGrey : _textDark,
                fontStyle: text.isEmpty ? FontStyle.italic : null,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Controls ──────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final bool isRecording, isPaused, isProcessing;
  final VoidCallback onStart, onPause, onResume, onStop;

  const _Controls({
    required this.isRecording,
    required this.isPaused,
    required this.isProcessing,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      32,
      20,
      32,
      MediaQuery.of(context).padding.bottom + 28,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.88),
      border: Border(top: BorderSide(color: _border, width: 1)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4A7CF5).withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isRecording && !isPaused && !isProcessing)
          _CtrlBtn(
            gradient: const LinearGradient(
              colors: [Color(0xFF6BAAF8), _deep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: _primary,
            icon: Icons.mic_rounded,
            size: 72,
            label: 'Start',
            onTap: onStart,
          )
        else if (isProcessing)
          _CtrlBtn(
            gradient: const LinearGradient(
              colors: [Color(0xFF6BAAF8), _deep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: _primary,
            icon: Icons.auto_awesome_rounded,
            size: 72,
            label: 'AI Processing…',
            onTap: null,
          )
        else ...[
          _CtrlBtn(
            color: const Color(0xFFF0F5FF),
            borderColor: _border,
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            iconColor: _textDark,
            size: 56,
            label: isPaused ? 'Resume' : 'Pause',
            onTap: isPaused ? onResume : onPause,
          ),
          const SizedBox(width: 24),
          _CtrlBtn(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5370), Color(0xFFFF2D55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: _error,
            icon: Icons.stop_rounded,
            size: 72,
            label: 'Done',
            onTap: onStop,
          ),
        ],
      ],
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final LinearGradient? gradient;
  final Color? color, borderColor, glowColor, iconColor;
  final IconData icon;
  final double size;
  final String label;
  final VoidCallback? onTap;

  const _CtrlBtn({
    this.gradient,
    this.color,
    this.borderColor,
    this.glowColor,
    required this.icon,
    this.iconColor,
    required this.size,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor!.withOpacity(0.32),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: size * 0.44,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _textGrey.withOpacity(0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ── Language Pill ─────────────────────────────────────────────────

class _LanguagePill extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LanguagePill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguageSheet(
        current: value,
        onSelect: (v) {
          onChanged(v);
          Navigator.pop(context);
        },
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_flag(value), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            value.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: _textGrey,
          ),
        ],
      ),
    ),
  );

  String _flag(String code) {
    switch (code) {
      case 'si':
      case 'ta':
        return '🇱🇰';
      default:
        return '🇬🇧';
    }
  }
}

class _LanguageSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _LanguageSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const langs = [
      ('en', '🇬🇧', 'English'),
      ('si', '🇱🇰', 'Sinhala'),
      ('ta', '🇱🇰', 'Tamil'),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...langs.map((l) {
            final (code, flag, name) = l;
            final sel = current == code;
            return GestureDetector(
              onTap: () => onSelect(code),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: sel ? _primary.withOpacity(0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? _primary : _border),
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sel ? _primary : _textDark,
                      ),
                    ),
                    const Spacer(),
                    if (sel)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
