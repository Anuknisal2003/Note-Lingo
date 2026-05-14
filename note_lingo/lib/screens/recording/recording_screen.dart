import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../providers/recording_provider.dart';
import '../../services/offline_queue_service.dart';
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
  RecordingQuality _quality = RecordingQuality.high;
  bool _vadEnabled = true;
  String _denoiseMethod = 'auto'; // 'auto', 'light', 'spectral', 'aggressive'
  double _denoiseStrength = 1.0; // 0.5 to 1.5

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

  Future<void> _showDraftsSheet(BuildContext context) async {
    final rp = context.read<RecordingProvider>();
    final drafts = await rp.listDrafts();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drafts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (drafts.isEmpty) ...[
              const Text('No drafts available.'),
            ] else ...[
              SizedBox(
                height: 240,
                child: ListView.separated(
                  itemCount: drafts.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) {
                    final d = drafts[i];
                    final t = d.updatedAt.toLocal().toString();
                    return ListTile(
                      title: Text('Draft ${d.id.substring(0, 8)}'),
                      subtitle: Text(t),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await rp.restoreDraft(d.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft restored')),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                            ),
                            child: const Text('Restore'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: _primary,
                            onPressed: () async {
                              await rp.deleteDraft(d.id);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft deleted')),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showOfflineItemsSheet(BuildContext context) async {
    final rp = context.read<RecordingProvider>();
    final pending = await rp.getPendingItems();
    final backoff = await rp.getBackoffItems();
    final failed = await rp.getFailedItems();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Offline Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (pending.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await rp.syncOfflineQueue();
                        await Future.delayed(const Duration(seconds: 2));
                        if (context.mounted) _showOfflineItemsSheet(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload, size: 16),
                      label: const Text('Sync Now'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (pending.isEmpty && backoff.isEmpty && failed.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No offline items',
                      style: TextStyle(color: _textGrey),
                    ),
                  ),
                ),
              ] else ...[
                // Pending items (ready to sync)
                if (pending.isNotEmpty) ...[
                  const Text(
                    'Ready to Sync',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pending.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: _border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (_, i) =>
                          _OfflineItemTile(item: pending[i], rp: rp),
                    ),
                  ),
                ],
                if (pending.isNotEmpty && backoff.isNotEmpty)
                  const SizedBox(height: 16),
                // Backoff items (waiting to retry)
                if (backoff.isNotEmpty) ...[
                  const Text(
                    'Waiting to Retry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _warning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: backoff.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: _border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (_, i) =>
                          _OfflineItemTile(item: backoff[i], rp: rp),
                    ),
                  ),
                ],
                if (failed.isNotEmpty) ...[
                  if (pending.isNotEmpty || backoff.isNotEmpty)
                    const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Failed (max retries reached)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _error,
                        ),
                      ),
                      // Retry all failed
                      TextButton.icon(
                        onPressed: () async {
                          for (final item in failed) {
                            await rp.resetFailedItem(item.id);
                          }
                          if (!context.mounted) return;
                          // ignore: use_build_context_synchronously
                          Navigator.pop(ctx);
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          if (context.mounted) {
                            await rp.syncOfflineQueue();
                            // ignore: use_build_context_synchronously
                            if (context.mounted) {
                              _showOfflineItemsSheet(context);
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _error,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text(
                          'Retry All',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _error.withValues(alpha: 0.2)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: failed.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: _border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (_, i) {
                        final item = failed[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _OfflineItemTile(item: item, rp: rp),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await rp.resetFailedItem(item.id);
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  await Future.delayed(
                                    const Duration(milliseconds: 300),
                                  );
                                  if (context.mounted) {
                                    await rp.syncOfflineQueue();
                                    if (context.mounted) {
                                      _showOfflineItemsSheet(context);
                                    }
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manualSyncOfflineItems() async {
    final rp = context.read<RecordingProvider>();
    if (rp.offlineQueueCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No offline items to sync.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sync started...')));
    await rp.syncOfflineQueue();
    if (!mounted) return;
    await rp.updateOfflineQueueCount();
    if (!mounted) return;

    final count = rp.offlineQueueCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'All offline items synced successfully.'
              : '$count item(s) still pending (retry/backoff).',
        ),
      ),
    );
  }

  Future<void> _onStop(RecordingProvider rp) async {
    await rp.stopRecording(category: _category, language: 'en');
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
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Keep Recording'),
          ),
          TextButton(
            onPressed: () {
              rp.cancelRecording();
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RecordingProvider>();

    return PopScope(
      canPop: !rp.isRecording && !rp.isPaused,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await _confirmDiscard(rp);
          if (ok && context.mounted) Navigator.pop(context);
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
                          style: IconButton.styleFrom(
                            foregroundColor: _primary,
                          ),
                          onPressed: () async {
                            final ok = await _confirmDiscard(rp);
                            if (ok && context.mounted) Navigator.pop(context);
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
                        // Drafts indicator + sheet
                        GestureDetector(
                          onTap: () => _showDraftsSheet(context),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Icon(Icons.save_rounded, color: _textDark),
                              if (rp.draftSaved)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    right: 2,
                                    top: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Offline items indicator + sheet
                        GestureDetector(
                          onTap: () => _showOfflineItemsSheet(context),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Icon(Icons.cloud_off_rounded, color: _textDark),
                              if (rp.offlineQueueCount > 0)
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: _error,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _error.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      rp.offlineQueueCount > 9
                                          ? '9+'
                                          : '${rp.offlineQueueCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  if (rp.offlineQueueCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_find,
                              size: 18,
                              color: _primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${rp.offlineQueueCount} offline item(s) pending',
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: rp.isProcessing
                                  ? null
                                  : _manualSyncOfflineItems,
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync Now'),
                            ),
                          ],
                        ),
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
                            const SizedBox(height: 12),
                            // Quality & audio options
                            _QualityAndAudioOptions(
                              quality: _quality,
                              vadEnabled: _vadEnabled,
                              denoiseMethod: _denoiseMethod,
                              denoiseStrength: _denoiseStrength,
                              onQualityChanged: (q) =>
                                  setState(() => _quality = q),
                              onVadChanged: (v) =>
                                  setState(() => _vadEnabled = v),
                              onDenoiseMethodChanged: (m) =>
                                  setState(() => _denoiseMethod = m),
                              onDenoiseStrengthChanged: (s) =>
                                  setState(() => _denoiseStrength = s),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // live transcript
                          if (rp.liveTranscript.isNotEmpty ||
                              rp.isRecording) ...[
                            _LiveTranscript(text: rp.liveTranscript),
                            const SizedBox(height: 24),
                          ],

                          // (processing logs removed - terminal-only)
                        ],
                      ),
                    ),
                  ),

                  // controls
                  _Controls(
                    isRecording: rp.isRecording,
                    isPaused: rp.isPaused,
                    isProcessing: rp.isProcessing,
                    onStart: () => rp.startRecordingWithOptions(
                      quality: _quality,
                      vadEnabled: _vadEnabled,
                      noiseCancellation: false,
                      denoiseMethod: _denoiseMethod,
                      denoiseStrength: _denoiseStrength,
                    ),
                    onPause: () => rp.pauseRecording(),
                    onResume: () => rp.resumeRecording(),
                    onStop: () => _onStop(rp),
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

class _QualityAndAudioOptions extends StatelessWidget {
  final RecordingQuality quality;
  final bool vadEnabled;
  final String denoiseMethod;
  final double denoiseStrength;
  final ValueChanged<RecordingQuality> onQualityChanged;
  final ValueChanged<bool> onVadChanged;
  final ValueChanged<String> onDenoiseMethodChanged;
  final ValueChanged<double> onDenoiseStrengthChanged;

  const _QualityAndAudioOptions({
    required this.quality,
    required this.vadEnabled,
    required this.denoiseMethod,
    required this.denoiseStrength,
    required this.onQualityChanged,
    required this.onVadChanged,
    required this.onDenoiseMethodChanged,
    required this.onDenoiseStrengthChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Recording Quality',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: DropdownButton<RecordingQuality>(
          value: quality,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: _cardBg,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            DropdownMenuItem(value: RecordingQuality.low, child: Text('Low')),
            DropdownMenuItem(
              value: RecordingQuality.medium,
              child: Text('Medium'),
            ),
            DropdownMenuItem(value: RecordingQuality.high, child: Text('High')),
          ],
          onChanged: (v) {
            if (v != null) onQualityChanged(v);
          },
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Expanded(
              child: Text(
                'VAD (auto-stop)',
                style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: vadEnabled,
              activeThumbColor: _primary,
              activeTrackColor: _primary.withValues(alpha: 0.35),
              onChanged: onVadChanged,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Denoise method selector
      const Text(
        'Noise Reduction',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: DropdownButton<String>(
          value: denoiseMethod,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: _cardBg,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'spectral', child: Text('Spectral')),
            DropdownMenuItem(value: 'aggressive', child: Text('Aggressive')),
          ],
          onChanged: (v) {
            if (v != null) onDenoiseMethodChanged(v);
          },
        ),
      ),
      const SizedBox(height: 12),
      // Denoise strength slider
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Text(
              'Strength: ${denoiseStrength.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontSize: 12,
                color: _textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _primary,
                  inactiveTrackColor: _border,
                  thumbColor: _primary,
                  overlayColor: _primary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: denoiseStrength,
                  min: 0.5,
                  max: 1.5,
                  divisions: 5,
                  onChanged: onDenoiseStrengthChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
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
            builder: (_, _) => Container(
              width: 160 + pulseAnim.value * 36,
              height: 160 + pulseAnim.value * 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _error.withValues(alpha: 0.22 * (1 - pulseAnim.value)),
                  width: 2,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, _) => Container(
              width: 130 + pulseAnim.value * 20,
              height: 130 + pulseAnim.value * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _error.withValues(alpha: 0.05 + pulseAnim.value * 0.04),
              ),
            ),
          ),
        ],
        if (isProcessing)
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              color: _primary.withValues(alpha: 0.30),
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
                color: (isRecording ? _error : _primary).withValues(
                  alpha: 0.38,
                ),
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
          separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                  color: active ? null : _cardBg.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: active ? _primary : _border),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.28),
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
      color: _cardBg.withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4A7CF5).withValues(alpha: 0.07),
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
      8,
      20,
      8,
      MediaQuery.of(context).padding.bottom + 28,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      border: Border(top: BorderSide(color: _border, width: 1)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4A7CF5).withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isRecording && !isPaused && !isProcessing)
            _CtrlBtn(
              color: _primary,
              icon: Icons.mic_rounded,
              size: 72,
              label: 'Start',
              onTap: onStart,
            )
          else if (isProcessing)
            _CtrlBtn(
              color: _primary,
              icon: Icons.auto_awesome_rounded,
              size: 72,
              label: 'AI Processing…',
              onTap: null,
            )
          else ...[
            _CtrlBtn(
              color: _primary,
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              iconColor: Colors.white,
              size: 56,
              label: isPaused ? 'Resume' : 'Pause',
              onTap: isPaused ? onResume : onPause,
            ),
            const SizedBox(width: 24),
            _CtrlBtn(
              color: _primary,
              icon: Icons.stop_rounded,
              size: 72,
              label: 'Done',
              onTap: onStop,
            ),
          ],
        ],
      ),
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final Color? color, iconColor;
  final IconData icon;
  final double size;
  final String label;
  final VoidCallback? onTap;

  const _CtrlBtn({
    this.color,
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
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.24),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
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
            color: _textGrey.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ── Language Pill ─────────────────────────────────────────────────
// ignore: unused_element
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
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _languageName(value),
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

  String _languageName(String code) {
    switch (code) {
      case 'si':
        return 'Sinhala';
      case 'ta':
        return 'Tamil';
      default:
        return 'English';
    }
  }
}

class _LanguageSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _LanguageSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const langs = [('en', 'English'), ('si', 'Sinhala'), ('ta', 'Tamil')];
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
            final (code, name) = l;
            final sel = current == code;
            return GestureDetector(
              onTap: () {
                if (code != 'en') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name language will be available soon.'),
                    ),
                  );
                  return;
                }
                onSelect(code);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: sel ? _primary.withValues(alpha: 0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? _primary : _border),
                ),
                child: Row(
                  children: [
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

// ── Offline Item Tile ─────────────────────────────────────────────

class _OfflineItemTile extends StatelessWidget {
  final OfflineQueueItem item;
  final RecordingProvider rp;

  const _OfflineItemTile({required this.item, required this.rp});

  String _getCategoryEmoji(NoteCategory cat) {
    switch (cat) {
      case NoteCategory.lecture:
        return '🎓';
      case NoteCategory.meeting:
        return '👥';
      case NoteCategory.interview:
        return '🎤';
      case NoteCategory.personal:
        return '💭';
      case NoteCategory.other:
        return '📝';
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final isReady = item.isReadyToRetry();
    final delaySeconds = item.getRetryDelaySeconds();
    final created = item.createdAt;
    final now = DateTime.now();
    final diff = now.difference(created);
    final durStr = _formatDuration(diff.inSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getCategoryEmoji(item.category),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _textGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.language == 'en'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.language.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.language == 'en'
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recording: $durStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isReady
                          ? Colors.green.withValues(alpha: 0.15)
                          : _warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isReady ? 'Ready' : 'Waiting',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isReady
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Retry ${item.retries}/3',
                    style: const TextStyle(fontSize: 10, color: _textGrey),
                  ),
                ],
              ),
            ],
          ),
          if (!isReady && delaySeconds > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Retrying in ${delaySeconds}s...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ActivityLogCard removed: logs are now terminal-only
