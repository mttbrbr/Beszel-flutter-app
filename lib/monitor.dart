import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  await _plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
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
      ),
    );

/// Fetches systems, fires notifications for newly triggered rules,
/// and returns the fresh list. Safe to call from a background isolate.
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
  final now = <String>{};
  final pending = <Future<void>>[];

  for (final s in systems) {
    final r = rules[s.id];
    if (r == null) continue;
    void trig(String key, bool cond, String Function() msg) {
      if (!cond) return;
      final k = '${s.id}:$key';
      now.add(k);
      if (!previous.contains(k)) pending.add(_notify(s.name, msg()));
    }

    trig('down', r.down && s.status == 'down', () => 'Il dispositivo è offline');
    if (!s.isUp) continue; // metrics are stale when not up
    trig('cpu', r.cpu != null && (s.cpu ?? 0) >= r.cpu!, () => 'CPU al ${s.cpu?.toStringAsFixed(0)}% (soglia ${r.cpu!.toStringAsFixed(0)}%)');
    trig('mem', r.mem != null && (s.mem ?? 0) >= r.mem!, () => 'RAM al ${s.mem?.toStringAsFixed(0)}% (soglia ${r.mem!.toStringAsFixed(0)}%)');
    trig('disk', r.disk != null && (s.disk ?? 0) >= r.disk!, () => 'Disco al ${s.disk?.toStringAsFixed(0)}% (soglia ${r.disk!.toStringAsFixed(0)}%)');
    trig('temp', r.temp != null && s.temp != null && s.temp! >= r.temp!, () => 'Temperatura ${s.temp?.toStringAsFixed(0)}°C (soglia ${r.temp!.toStringAsFixed(0)}°C)');
  }
  await Future.wait(pending);
  await Store.saveActive(now);
  return systems;
}
