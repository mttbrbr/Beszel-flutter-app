import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show themeNotifier;
import '../models.dart';
import '../monitor.dart';
import '../storage.dart';
import 'device.dart';
import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<BeszelSystem>? _systems;
  Map<String, AlertRules> _rules = {};
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await checkAndNotify();
      final rules = await Store.rules();
      if (mounted) setState(() { _systems = list; _rules = rules; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _logout() async {
    await Store.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final systems = _systems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivi', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, m, __) => IconButton(
              tooltip: 'Tema',
              icon: Icon(switch (m) { ThemeMode.dark => Icons.dark_mode, ThemeMode.light => Icons.light_mode, _ => Icons.brightness_auto }),
              onPressed: () {
                final next = switch (m) { ThemeMode.dark => ThemeMode.light, ThemeMode.light => ThemeMode.system, _ => ThemeMode.dark };
                themeNotifier.value = next;
                Store.saveThemeMode(next);
              },
            ),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Esci'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: systems == null
            ? ListView(children: [
                SizedBox(
                  height: 400,
                  child: Center(child: _error != null ? Text(_error!, style: TextStyle(color: cs.error)) : const CircularProgressIndicator()),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Offline: $_error', style: TextStyle(color: cs.error)),
                    ),
                  if (systems.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Nessun dispositivo'))),
                  for (final s in systems)
                    _SystemCard(
                      system: s,
                      hasRules: _rules[s.id]?.any ?? false,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceScreen(system: s)));
                        _refresh();
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final BeszelSystem system;
  final bool hasRules;
  final VoidCallback onTap;
  const _SystemCard({required this.system, required this.hasRules, required this.onTap});

  Color _statusColor() => switch (system.status) {
        'up' => const Color(0xFF22C55E),
        'down' => const Color(0xFFEF4444),
        _ => const Color(0xFF9CA3AF),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(system.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                Icon(hasRules ? Icons.notifications_active : Icons.notifications_none, size: 20, color: hasRules ? cs.primary : cs.onSurfaceVariant),
              ]),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(system.host, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
              if (system.isUp) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _Metric('CPU', system.cpu)),
                  const SizedBox(width: 14),
                  Expanded(child: _Metric('RAM', system.mem)),
                  const SizedBox(width: 14),
                  Expanded(child: _Metric('Disco', system.disk)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double? value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value ?? 0;
    final color = v >= 90 ? const Color(0xFFEF4444) : v >= 70 ? const Color(0xFFF59E0B) : cs.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value == null ? '–' : '${v.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: (v / 100).clamp(0, 1), minHeight: 6, color: color, backgroundColor: cs.surfaceContainerHighest),
      ),
    ]);
  }
}
