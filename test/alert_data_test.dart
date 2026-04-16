import 'package:flutter_test/flutter_test.dart';
import 'package:help_signal/utilities/alert_data.dart';

void main() {
  group('formatRelativeTime', () {
    test('pluralizes day labels', () {
      final now = DateTime(2026, 4, 13, 12);

      expect(
        formatRelativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2 days ago',
      );
    });

    test('collapses future timestamps to a safe label', () {
      final now = DateTime(2026, 4, 13, 12);

      expect(
        formatRelativeTime(now.add(const Duration(minutes: 5)), now: now),
        'Just now',
      );
    });
  });
}
