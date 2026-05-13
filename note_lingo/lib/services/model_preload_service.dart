// lib/services/model_preload_service.dart
// Manages model loading and caching on the local AI server

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_ai_service.dart';

/// Service to manage model preloading and cache optimization on Flask server.
class ModelPreloadService {
  static final ModelPreloadService _instance = ModelPreloadService._internal();
  factory ModelPreloadService() => _instance;
  ModelPreloadService._internal();

  final LocalAiService _ai = LocalAiService();
  bool _preloadInitiated = false;

  /// Trigger async model preload on server (returns immediately).
  /// Models will load in background while app continues.
  Future<bool> preloadModels() async {
    try {
      final baseUrl = await _ai.getBaseUrlOrNull();
      if (baseUrl == null) {
        debugPrint('[ModelPreloadService] Server not available for preload');
        return false;
      }

      final uri = Uri.parse('$baseUrl/preload');
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('timeout', 504),
          );

      if (res.statusCode == 202) {
        _preloadInitiated = true;
        debugPrint('[ModelPreloadService] Preload initiated (async)');
        return true;
      } else {
        debugPrint('[ModelPreloadService] Preload failed: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[ModelPreloadService] Preload error: $e');
      return false;
    }
  }

  /// Get cache statistics from server.
  Future<Map<String, bool>?> getCacheStats() async {
    try {
      final baseUrl = await _ai.getBaseUrlOrNull();
      if (baseUrl == null) return null;

      final uri = Uri.parse('$baseUrl/cache/stats');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, bool>;
        debugPrint('[ModelPreloadService] Cache stats: ${data['cache']}');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('[ModelPreloadService] Cache stats error: $e');
      return null;
    }
  }

  /// Clear server-side cache to free memory.
  Future<bool> clearCache() async {
    try {
      final baseUrl = await _ai.getBaseUrlOrNull();
      if (baseUrl == null) return false;

      final uri = Uri.parse('$baseUrl/cache/clear');
      final res = await http.post(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        debugPrint('[ModelPreloadService] Cache cleared');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ModelPreloadService] Cache clear error: $e');
      return false;
    }
  }

  /// Check if models are loaded on server.
  Future<Map<String, bool>?> checkModelStatus() async {
    try {
      final baseUrl = await _ai.getBaseUrlOrNull();
      if (baseUrl == null) return null;

      final uri = Uri.parse('$baseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, bool>;
        final status = {
          'whisper_loaded': data['whisper_loaded'] ?? false,
          'bart_loaded': data['bart_loaded'] ?? false,
        };
        debugPrint('[ModelPreloadService] Model status: $status');
        return status;
      }
      return null;
    } catch (e) {
      debugPrint('[ModelPreloadService] Model status error: $e');
      return null;
    }
  }

  /// Check if preload was initiated.
  bool get preloadInitiated => _preloadInitiated;

  /// Reset preload flag (for testing).
  void resetPreloadFlag() {
    _preloadInitiated = false;
  }
}
