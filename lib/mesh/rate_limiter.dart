/// Rate limiter for mesh rebroadcasts
///
/// Prevents flooding by limiting rebroadcasts per second.
/// Emergency priority messages bypass rate limiting.
class RateLimiter {
  final int maxRebroadcastsPerSecond;
  final int emergencyRebroadcastsPerSecond;

  final List<DateTime> _rebroadcastTimes = [];
  final List<DateTime> _emergencyRebroadcastTimes = [];

  RateLimiter({
    this.maxRebroadcastsPerSecond = 3,
    this.emergencyRebroadcastsPerSecond = 10,
  });

  /// Check if rebroadcast is allowed
  /// Returns true if the rebroadcast can proceed
  bool canRebroadcast({bool isEmergency = false}) {
    final now = DateTime.now();
    final threshold = Duration(seconds: 1);

    if (isEmergency) {
      // Remove old emergency entries
      _emergencyRebroadcastTimes.removeWhere(
        (t) => now.difference(t) > threshold,
      );

      if (_emergencyRebroadcastTimes.length < emergencyRebroadcastsPerSecond) {
        _emergencyRebroadcastTimes.add(now);
        return true;
      }
      return false;
    } else {
      // Remove old normal entries
      _rebroadcastTimes.removeWhere(
        (t) => now.difference(t) > threshold,
      );

      if (_rebroadcastTimes.length < maxRebroadcastsPerSecond) {
        _rebroadcastTimes.add(now);
        return true;
      }
      return false;
    }
  }

  /// Get random delay for rebroadcast (20-200ms)
  Duration getRandomDelay() {
    final random = DateTime.now().millisecondsSinceEpoch % 180 + 20;
    return Duration(milliseconds: random);
  }

  /// Get statistics
  String getStats() {
    return 'RateLimit: Normal ${_rebroadcastTimes.length}/$maxRebroadcastsPerSecond, '
        'Emergency ${_emergencyRebroadcastTimes.length}/$emergencyRebroadcastsPerSecond';
  }

  /// Clear statistics
  void reset() {
    _rebroadcastTimes.clear();
    _emergencyRebroadcastTimes.clear();
  }
}
