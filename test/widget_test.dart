import 'package:flutter_test/flutter_test.dart';

import 'package:help_signal/main.dart';

void main() {
  testWidgets('HelpSignal shows main navigation tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HelpSignal'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
  });
}
