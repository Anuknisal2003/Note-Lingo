import 'dart:math';

/// Retry backoff strategy with exponential backoff and jitter.
class RetryBackoffService {
  static const int _initialDelaySeconds = 5;
  static const int _maxDelaySeconds = 3600; // 1 hour
  static const double _backoffMultiplier = 1.5;

  /// Calculate next retry delay based on retry count.
  /// Returns delay in seconds; returns 0 if ready to retry.
  static int getBackoffDelay(int retryCount, DateTime? lastRetryTime) {
    if (lastRetryTime == null) {
      return 0; // No previous retry, can retry immediately
    }

    // Calculate base delay: 5s * 1.5^retryCount, capped at 1 hour
    final baseDelay =
        (_initialDelaySeconds *
                pow(_backoffMultiplier, retryCount.clamp(0, 20)))
            .toInt()
            .clamp(0, _maxDelaySeconds);

    // Add jitter: ±20% of base delay
    final jitter = (baseDelay * 0.2 * (Random().nextDouble() * 2 - 1)).toInt();
    final totalDelay = (baseDelay + jitter).clamp(0, _maxDelaySeconds);

    // Time elapsed since last retry
    final elapsed = DateTime.now().difference(lastRetryTime).inSeconds;

    // Return remaining delay (0 if ready)
    return max(0, totalDelay - elapsed);
  }

  /// Check if ready to retry based on retry count and last attempt time.
  static bool isReadyToRetry(int retryCount, DateTime? lastRetryTime) {
    return getBackoffDelay(retryCount, lastRetryTime) == 0;
  }

  /// Format backoff delay as human-readable string.
  static String formatDelay(int delaySeconds) {
    if (delaySeconds < 60) return '${delaySeconds}s';
    if (delaySeconds < 3600) return '${delaySeconds ~/ 60}m';
    return '${delaySeconds ~/ 3600}h';
  }
}
