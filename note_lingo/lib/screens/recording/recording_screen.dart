import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/note_model.dart';
import '../../providers/recording_provider.dart';
import '../../providers/language_provider.dart';
import '../note_detail/note_detail_screen.dart';

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

  void _onStop(BuildContext ctx, RecordingProvider rp) async {
    await rp.stopRecording(category: _category);
    if (!mounted) return;

    if (rp.processedNote != null) {
      final note = rp.processedNote!;
      rp.clearProcessed();
      Navigator.of(ctx).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NoteDetailScreen(note: note, isNew: true),
        ),
      );
    }
  }

  Future<bool> _onWillPop(RecordingProvider rp) async {
    if (!rp.isRecording) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text('Your current recording will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              rp.cancelRecording();
              Navigator.pop(context, true);
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
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
      canPop: !rp.isRecording,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop(rp);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _onWillPop(rp)) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          title: const Text('New Recording'),
          actions: [
            _LanguagePill(
              value: lang.selectedLanguage,
              onChanged: (v) => lang.setLanguage(v),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Visualizer
                    _RecordVisualizer(
                      isRecording: rp.isRecording,
                      isPaused: rp.isPaused,
                      isProcessing: rp.isProcessing,
                      pulseAnim: _pulseAnim,
                      waveCtrl: _waveCtrl,
                    ),
                    const SizedBox(height: 28),

                    // Timer
                    Text(
                      rp.formattedTime,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusLabel(
                      isRecording: rp.isRecording,
                      isPaused: rp.isPaused,
                      isProcessing: rp.isProcessing,
                      processingStatus: rp.processingStatus,
                    ),
                    const SizedBox(height: 32),

                    // Category (only when idle)
                    if (!rp.isRecording &&
                        !rp.isPaused &&
                        !rp.isProcessing) ...[
                      _CategorySelector(
                        selected: _category,
                        onChanged: (c) => setState(() => _category = c),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Live transcript
                    if (rp.liveTranscript.isNotEmpty || rp.isRecording) ...[
                      _LiveTranscript(text: rp.liveTranscript),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),

            // Controls
            _Controls(
              isRecording: rp.isRecording,
              isPaused: rp.isPaused,
              isProcessing: rp.isProcessing,
              onStart: () => rp.startRecording(),
              onPause: () => rp.pauseRecording(),
              onResume: () => rp.resumeRecording(),
              onStop: () => _onStop(context, rp),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visualizer ────────────────────────────────────────────────────

class _RecordVisualizer extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final bool isProcessing;
  final Animation<double> pulseAnim;
  final AnimationController waveCtrl;

  const _RecordVisualizer({
    required this.isRecording,
    required this.isPaused,
    required this.isProcessing,
    required this.pulseAnim,
    required this.waveCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                    color: AppColors.error.withOpacity(
                      0.25 * (1 - pulseAnim.value),
                    ),
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
                  color: AppColors.error.withOpacity(
                    0.06 + pulseAnim.value * 0.04,
                  ),
                ),
              ),
            ),
          ],
          if (isProcessing) ...[
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                color: AppColors.primary.withOpacity(0.3),
                strokeWidth: 2,
              ),
            ),
          ],
          // Main circle button
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: isRecording
                  ? AppColors.recordGradient
                  : isProcessing
                  ? AppColors.primaryGradient
                  : AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.error : AppColors.primary)
                      .withOpacity(0.4),
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
}

// ── Status Label ─────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final bool isProcessing;
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
      label = processingStatus;
      color = AppColors.primary;
    } else if (isPaused) {
      label = 'Paused — tap Resume to continue';
      color = AppColors.warning;
    } else if (isRecording) {
      label = '● Recording — speak clearly';
      color = AppColors.error;
    } else {
      label = 'Ready to record';
      color = AppColors.textMuted;
    }

    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      textAlign: TextAlign.center,
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Note Category', style: Theme.of(context).textTheme.titleMedium),
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
                    gradient: active ? AppColors.primaryGradient : null,
                    color: active ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.bgBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary,
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
}

// ── Live Transcript ───────────────────────────────────────────────

class _LiveTranscript extends StatelessWidget {
  final String text;
  const _LiveTranscript({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Transcript',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.isEmpty ? 'Listening...' : text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: text.isEmpty ? AppColors.textMuted : null,
              fontStyle: text.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        32,
        20,
        32,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.bgBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isRecording && !isPaused && !isProcessing)
            _CtrlBtn(
              gradient: AppColors.primaryGradient,
              glowColor: AppColors.primary,
              icon: Icons.mic_rounded,
              size: 72,
              label: 'Start',
              onTap: onStart,
            )
          else if (isProcessing)
            _CtrlBtn(
              gradient: AppColors.primaryGradient,
              glowColor: AppColors.primary,
              icon: Icons.hourglass_top_rounded,
              size: 72,
              label: 'Processing...',
              onTap: null,
            )
          else ...[
            _CtrlBtn(
              color: AppColors.bgSurface,
              borderColor: AppColors.bgBorder,
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              iconColor: AppColors.textPrimary,
              size: 56,
              label: isPaused ? 'Resume' : 'Pause',
              onTap: isPaused ? onResume : onPause,
            ),
            const SizedBox(width: 24),
            _CtrlBtn(
              gradient: AppColors.recordGradient,
              glowColor: AppColors.error,
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
}

class _CtrlBtn extends StatelessWidget {
  final LinearGradient? gradient;
  final Color? color;
  final Color? borderColor;
  final Color? glowColor;
  final IconData icon;
  final Color? iconColor;
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
                        color: glowColor!.withOpacity(0.35),
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
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Language Pill ─────────────────────────────────────────────────

class _LanguagePill extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LanguagePill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.bgCard,
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
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_flag(value), style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              value.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _flag(String code) {
    switch (code) {
      case 'si':
        return '🇱🇰';
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
    final langs = [
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
          Text(
            'Select Language',
            style: Theme.of(context).textTheme.headlineSmall,
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
                  color: sel
                      ? AppColors.primary.withOpacity(0.12)
                      : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.bgBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (sel)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
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
