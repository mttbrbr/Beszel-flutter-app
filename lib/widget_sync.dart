import 'dart:convert';
import 'dart:io' show Platform;
import 'package:home_widget/home_widget.dart';
import 'models.dart';

const _providers = [
  'MachineWidgetProvider',
  'MachineBarsWidgetProvider',
  'MachineStatusWidgetProvider',
  'FleetStatusWidgetProvider',
  'OverallWidgetProvider',
  'FleetWidgetProvider',
];

/// Pushes the latest device data to the Android home-screen widgets.
/// The native providers read the JSON from HomeWidget's shared preferences.
Future<void> syncHomeWidgets(List<BeszelSystem> systems, int activeAlerts) async {
  if (!Platform.isAndroid) return;
  try {
    final data = [
      for (final s in systems)
        {'id': s.id, 'name': s.name, 'status': s.status, 'cpu': s.cpu, 'mem': s.mem, 'disk': s.disk, 'temp': s.temp},
    ];
    await HomeWidget.saveWidgetData<String>('systems_json', jsonEncode(data));
    await HomeWidget.saveWidgetData<int>('alerts', activeAlerts);
    await HomeWidget.saveWidgetData<int>('updated_at', DateTime.now().millisecondsSinceEpoch);
    for (final p in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: 'dev.beszel.beszel_app.$p');
    }
  } catch (_) {
    // Widgets are best-effort; never break monitoring because of them.
  }
}
