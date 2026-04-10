/// LRU deduplication cache for mesh packet IDs
///
/// Maintains a set of recently seen message IDs to prevent processing duplicates.
/// Uses LRU eviction when cache exceeds maxSize.
/// Entries automatically expire after maxAge duration.
class DeduplicationCache {
  final int maxSize;
  final Duration maxAge;

  final Map<int, DateTime> _cache = {};
  final List<int> _lruOrder = [];

  DeduplicationCache({
    this.maxSize = 500,
    this.maxAge = const Duration(minutes: 5),
  });

  /// Check if message ID has been seen before
  bool contains(int messageId) {
    _expireOldEntries();
    return _cache.containsKey(messageId);
  }

  /// Add message ID to cache
  void add(int messageId) {
    _expireOldEntries();

    if (_cache.containsKey(messageId)) {
      // Move to end (most recent)
      _lruOrder.remove(messageId);
      _lruOrder.add(messageId);
      _cache[messageId] = DateTime.now();
      return;
    }

    // Add new entry
    _cache[messageId] = DateTime.now();
    _lruOrder.add(messageId);

    // Evict LRU if cache exceeds max size
    if (_cache.length > maxSize) {
      final lruId = _lruOrder.removeAt(0);
      _cache.remove(lruId);
    }
  }

  /// Remove all expired entries
  void _expireOldEntries() {
    final now = DateTime.now();
    final expired = <int>[];

    _cache.forEach((id, addedAt) {
      if (now.difference(addedAt) > maxAge) {
        expired.add(id);
      }
    });

    for (final id in expired) {
      _cache.remove(id);
      _lruOrder.remove(id);
    }
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
    _lruOrder.clear();
  }

  /// Get cache size
  int get size => _cache.length;

  /// Get cache hit statistics
  String getStats() {
    return 'Cache: ${_cache.length}/$maxSize entries, '
        'oldest: ${_lruOrder.isNotEmpty ? _cache[_lruOrder.first]?.toString() ?? "unknown" : "empty"}';
  }
}
