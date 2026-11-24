import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'monitor.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'storage.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

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
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _bgTask,
    _bgTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  themeNotifier.value = await Store.themeMode();
  final session = await Store.session();
  runApp(BeszelApp(loggedIn: session != null));
}

class BeszelApp extends StatelessWidget {
  final bool loggedIn;
  const BeszelApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF), brightness: b),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Beszel',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark).copyWith(scaffoldBackgroundColor: const Color(0xFF0B1220)),
        home: loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
