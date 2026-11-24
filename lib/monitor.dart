import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'widget_sync.dart';

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  await _plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Apri'),
    ),
  );
}

Future<void> requestNotificationPermission() async {
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

Future<void> _notify(String title, String body) => _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'beszel_alerts',
          'Alert Beszel',
          channelDescription: 'Notifiche sui trigger dei dispositivi',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );

/// A rule that is currently violated on a device.
class ActiveAlert {
  final BeszelSystem system;
  final String key; // down | cpu | mem | disk | temp
  final String message;
  const ActiveAlert(this.system, this.key, this.message);
  String get id => '${system.id}:$key';
}

/// Evaluates every device against its alert rules.
List<ActiveAlert> evaluateAlerts(List<BeszelSystem> systems, Map<String, AlertRules> rules) {
  final out = <ActiveAlert>[];
  for (final s in systems) {
    final r = rules[s.id];
    if (r == null) continue;
    if (r.down && s.status == 'down') out.add(ActiveAlert(s, 'down', 'Il dispositivo è offline'));
    if (!s.isUp) continue; // metrics are stale when not up
    String pct(double v) => v.toStringAsFixed(0);
    if (r.cpu != null && (s.cpu ?? 0) >= r.cpu!) out.add(ActiveAlert(s, 'cpu', 'CPU al ${pct(s.cpu!)}% (soglia ${pct(r.cpu!)}%)'));
    if (r.mem != null && (s.mem ?? 0) >= r.mem!) out.add(ActiveAlert(s, 'mem', 'RAM al ${pct(s.mem!)}% (soglia ${pct(r.mem!)}%)'));
    if (r.disk != null && (s.disk ?? 0) >= r.disk!) out.add(ActiveAlert(s, 'disk', 'Disco al ${pct(s.disk!)}% (soglia ${pct(r.disk!)}%)'));
    if (r.temp != null && s.temp != null && s.temp! >= r.temp!) out.add(ActiveAlert(s, 'temp', 'Temperatura ${pct(s.temp!)}°C (soglia ${pct(r.temp!)}°C)'));
  }
  return out;
}

/// Fetches systems, fires notifications for newly triggered rules,
/// refreshes the home-screen widgets and returns the fresh list.
/// Safe to call from a background isolate.
Future<List<BeszelSystem>> checkAndNotify() async {
  var api = await Store.api();
  if (api == null) return [];
  List<BeszelSystem> systems;
  try {
    systems = await api.systems();
  } on ApiException catch (e) {
    if (e.status != 401 && e.status != 403) rethrow;
    api = await Store.api(forceLogin: true);
    systems = await api!.systems();
  }

  final rules = await Store.rules();
  final previous = await Store.active();
  final alerts = evaluateAlerts(systems, rules);
  await Future.wait([
    for (final a in alerts)
      if (!previous.contains(a.id)) _notify(a.system.name, a.message),
  ]);
  await Store.saveActive(alerts.map((a) => a.id).toSet());
  await syncHomeWidgets(systems, alerts.length);
  return systems;
}
