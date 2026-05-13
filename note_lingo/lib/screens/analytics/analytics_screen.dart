import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/analytics_provider.dart';
import '../../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));

    // Load analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadAllAnalytics(_startDate, _endDate);
    });
  }

  void _updateDateRange(int days) {
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(Duration(days: days));
    context.read<AnalyticsProvider>().updateDateRange(_startDate, _endDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.bgDark,
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Text(
                provider.error!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date range selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DateRangeButton('7d', 7, _updateDateRange),
                      _DateRangeButton('30d', 30, _updateDateRange),
                      _DateRangeButton('90d', 90, _updateDateRange),
                      _DateRangeButton('1y', 365, _updateDateRange),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Progress stats
                if (provider.progressStats != null)
                  _ProgressStatsCard(stats: provider.progressStats!),
                const SizedBox(height: 20),

                // Category breakdown
                if (provider.categoryStats != null)
                  _CategoryStatsCard(stats: provider.categoryStats!),
                const SizedBox(height: 20),

                // Word frequency
                if (provider.wordFrequencies != null &&
                    provider.wordFrequencies!.isNotEmpty)
                  _WordFrequencyCard(frequencies: provider.wordFrequencies!),
                const SizedBox(height: 20),

                // Favorite stats
                if (provider.favoriteStats != null)
                  _FavoriteStatsCard(stats: provider.favoriteStats!),
                const SizedBox(height: 20),

                // WER Score
                _WerScoreCard(score: provider.werScore),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final String label;
  final int days;
  final Function(int) onTap;

  const _DateRangeButton(this.label, this.days, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => onTap(days),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ProgressStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _ProgressStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Progress Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StatRow('Total Notes', '${stats['totalNotes'] ?? 0}'),
          _StatRow('Total Minutes', '${stats['totalMinutes'] ?? 0}'),
          _StatRow('Total Words', '${stats['totalWords'] ?? 0}'),
          _StatRow('Current Streak', '${stats['currentStreak'] ?? 0} days'),
          _StatRow(
            'Avg/Day',
            '${(stats['averageNotesPerDay'] ?? 0.0).toStringAsFixed(1)}',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CategoryStatsCard extends StatelessWidget {
  final Map<String, int> stats;

  const _CategoryStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📁 By Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...stats.entries.map((e) => _StatRow(e.key, '${e.value} notes')),
        ],
      ),
    );
  }
}

class _WordFrequencyCard extends StatelessWidget {
  final List<WordFrequency> frequencies;

  const _WordFrequencyCard({required this.frequencies});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏷️ Top Words',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: frequencies.take(10).map((freq) {
              return Chip(
                label: Text('${freq.word} (${freq.count})'),
                backgroundColor: AppColors.accent.withValues(alpha: 0.3),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FavoriteStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _FavoriteStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final favorited = stats['favorited'] ?? 0;
    final percentage = stats['percentage'] ?? '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⭐ Favorites',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StatRow('Favorited', '$favorited of $total ($percentage%)'),
        ],
      ),
    );
  }
}

class _WerScoreCard extends StatelessWidget {
  final double score;

  const _WerScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Transcription Accuracy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StatRow('WER Score', '${(score * 100).toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation(
              score > 0.9
                  ? Colors.green
                  : score > 0.8
                  ? Colors.orange
                  : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
