import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'monitor.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'storage.dart';
import 'theme.dart';

const _bgTask = 'beszel_check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await initNotifications();
      await checkAndNotify();
    } catch (_) {}
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  // Background polling only exists on mobile; on desktop the app polls while open.
  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _bgTask,
      _bgTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  final session = await Store.session();
  runApp(BeszelApp(loggedIn: session != null));
}

class BeszelApp extends StatelessWidget {
  final bool loggedIn;
  const BeszelApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Beszel',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: beszelTheme(),
        theme: beszelTheme(),
        home: loggedIn ? const HomeScreen() : const LoginScreen(),
      );
}
