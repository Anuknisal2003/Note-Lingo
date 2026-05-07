import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_enhancements_provider.dart';
import '../../services/enhanced_ai_service.dart';

class AiEnhancementsScreen extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final String noteText;

  const AiEnhancementsScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteText,
  });

  @override
  State<AiEnhancementsScreen> createState() => _AiEnhancementsScreenState();
}

class _AiEnhancementsScreenState extends State<AiEnhancementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiEnhancementsProvider>().analyzeNote(
        widget.noteText,
        widget.noteId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Analysis - ${widget.noteTitle}'),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.bgDark,
      body: Consumer<AiEnhancementsProvider>(
        builder: (context, provider, _) {
          if (provider.isAnalyzing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(provider.analysisStatus),
                ],
              ),
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

          final enhancement = provider.enhancement;
          if (enhancement == null) {
            return const Center(child: Text('No analysis available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sentiment
                _SentimentCard(
                  sentiment: enhancement.sentiment,
                  score: enhancement.sentimentScore,
                ),
                const SizedBox(height: 16),

                // Speakers
                if (enhancement.speakers.isNotEmpty)
                  _SpeakersCard(speakers: enhancement.speakers),
                const SizedBox(height: 16),

                // Q&A
                _QaCard(qaItems: enhancement.qaItems),
                const SizedBox(height: 16),

                // Entities
                if (enhancement.entities.isNotEmpty)
                  _EntitiesCard(
                    entities: enhancement.entities,
                    counts: enhancement.entityCounts,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  final String sentiment;
  final double score;

  const _SentimentCard({required this.sentiment, required this.score});

  String get emoji {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😞';
      default:
        return '😐';
    }
  }

  Color get color {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

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
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sentiment Analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    sentiment.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score,
                    minHeight: 8,
                    backgroundColor: Colors.grey[700],
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(score * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeakersCard extends StatelessWidget {
  final List<String> speakers;

  const _SpeakersCard({required this.speakers});

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
            '🎙️ Speakers Detected',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: speakers.map((speaker) {
              return Chip(
                label: Text(speaker),
                backgroundColor: AppColors.accent.withOpacity(0.3),
                avatar: const Icon(Icons.person, size: 18),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _QaCard extends StatelessWidget {
  final List<QaItem> qaItems;

  const _QaCard({required this.qaItems});

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
            '❓ Q&A Extracted',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (qaItems.isEmpty)
            Text(
              'No Q&A was generated for this note yet.',
              style: TextStyle(color: Colors.grey[400]),
            )
          else
            ...qaItems.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final qa = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q$index: ${qa.question}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A: ${qa.answer}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }
}

class _EntitiesCard extends StatelessWidget {
  final List<String> entities;
  final Map<String, int> counts;

  const _EntitiesCard({required this.entities, required this.counts});

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
            '🏷️ Named Entities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entities.map((entity) {
              final count = counts[entity] ?? 1;
              return Chip(
                label: Text('$entity (${count}x)'),
                backgroundColor: AppColors.accent.withOpacity(0.2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
