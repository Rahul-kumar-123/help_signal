import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:help_signal/core/alert_controller.dart';
import 'package:help_signal/core/alert_manager.dart';
import 'package:help_signal/core/location_manager.dart';
import 'package:help_signal/core/mesh_manager.dart';
import 'package:help_signal/main.dart';
import 'package:help_signal/utilities/alert_data.dart';

void main() {
  testWidgets('HelpSignal shows main navigation tabs', (
    WidgetTester tester,
  ) async {
    final controller = AlertController(
      alertManager: _WidgetTestAlertManager(),
      meshManager: _WidgetTestMeshManager(),
      locationManager: _WidgetTestLocationManager(),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HelpSignal'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);

    controller.dispose();
  });
}

class _WidgetTestAlertManager extends AlertManager {
  @override
  Future<void> initialize() async {}
}

class _WidgetTestMeshManager extends MeshManager {
  @override
  Future<void> initialize({
    required String localSenderId,
    required MeshAlertHandler onAlertReceived,
    required MeshStateListener onStateChanged,
    Iterable<String> restoredProcessedMessageIds = const <String>[],
    List<AlertMessage> restoredPendingAlerts = const <AlertMessage>[],
    PendingAlertsPersistenceHandler? onPendingAlertsChanged,
  }) async {
    onStateChanged(
      const MeshNetworkState(
        bluetoothSupported: false,
        statusMessage: 'Mesh unavailable in widget tests',
      ),
    );
  }
}

class _WidgetTestLocationManager extends LocationManager {
  @override
  Future<LatLng?> getCurrentLocation() async => const LatLng(12.9716, 77.5946);
}
