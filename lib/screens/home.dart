import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../monitor.dart';
import '../storage.dart';
import '../theme.dart';
import 'alerts.dart';
import 'device.dart';
import 'sparkline.dart';
import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<BeszelSystem>? _systems;
  Map<String, AlertRules> _rules = {};
  final Map<String, List<double>> _spark = {};
  DateTime _sparkAt = DateTime.fromMillisecondsSinceEpoch(0);
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
      _loadSparks(list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// CPU history (last hour) for the card sparklines; refreshed at most once a minute.
  Future<void> _loadSparks(List<BeszelSystem> list) async {
    if (DateTime.now().difference(_sparkAt) < const Duration(seconds: 60)) return;
    _sparkAt = DateTime.now();
    try {
      final api = await Store.api();
      if (api == null) return;
      final res = await Future.wait([
        for (final s in list.where((s) => s.isUp))
          api.stats(s.id, StatRange.h1).then((pts) => MapEntry(s.id, [for (final p in pts) p.cpu ?? 0.0])),
      ]);
      if (mounted) setState(() => _spark..clear()..addEntries(res));
    } catch (_) {
      _sparkAt = DateTime.fromMillisecondsSinceEpoch(0); // retry on next refresh
    }
  }

  Future<void> _logout() async {
    await Store.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  List<Widget> _alertBanner(List<BeszelSystem> systems) {
    final alerts = evaluateAlerts(systems, _rules);
    if (alerts.isEmpty) return const [];
    return [
      BzCard(
        accent: Bz.red,
        margin: const EdgeInsets.only(bottom: 16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlertsScreen(alerts: alerts))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Bz.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alerts.length == 1 ? '1 avviso attivo' : '${alerts.length} avvisi attivi',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Bz.red),
            ),
          ),
          const Icon(Icons.chevron_right, color: Bz.muted),
        ]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final systems = _systems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beszel'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Esci'),
        ],
      ),
      body: AmbientBackground(child: RefreshIndicator(
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
                  if (systems.isNotEmpty) _FleetSummary(systems),
                  ..._alertBanner(systems),
                  if (systems.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Nessun dispositivo'))),
                  for (final s in systems)
                    _SystemCard(
                      system: s,
                      hasRules: _rules[s.id]?.any ?? false,
                      spark: _spark[s.id],
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceScreen(system: s)));
                        _refresh();
                      },
                    ),
                ],
              ),
      )),
    );
  }
}

class _FleetSummary extends StatelessWidget {
  final List<BeszelSystem> systems;
  const _FleetSummary(this.systems);

  @override
  Widget build(BuildContext context) {
    final up = systems.where((s) => s.isUp).length;
    final down = systems.where((s) => s.status == 'down').length;
    final total = systems.length;
    final healthy = down == 0;
    final color = healthy ? Bz.green : Bz.red;
    return BzCard(
      accent: healthy ? null : Bz.red,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(healthy ? 'Tutto in ordine' : '$down offline', color),
          const Spacer(),
          Text('$up/$total online', style: const TextStyle(color: Bz.muted, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final BeszelSystem system;
  final bool hasRules;
  final List<double>? spark;
  final VoidCallback onTap;
  const _SystemCard({required this.system, required this.hasRules, required this.onTap, this.spark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Bz.status(system.status);
    return BzCard(
      accent: system.status == 'down' ? Bz.red : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(system.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(system.host, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
              ]),
            ),
            if (system.isUp && system.temp != null) ...[
              Text('${system.temp!.round()}°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: system.temp! >= 75 ? Bz.red : Bz.muted)),
              const SizedBox(width: 10),
            ],
            if (hasRules) ...[
              const Icon(Icons.notifications_active, size: 16, color: Bz.accent),
              const SizedBox(width: 10),
            ],
            Pill(switch (system.status) { 'up' => 'Online', 'down' => 'Offline', _ => system.status }, color),
          ]),
          if (system.isUp) ...[
            if (spark != null && spark!.length > 1) ...[
              const SizedBox(height: 12),
              Sparkline(values: spark!, color: Bz.load(system.cpu ?? 0)),
            ],
            const SizedBox(height: 14),
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
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double? value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final color = Bz.load(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11.5, color: Bz.muted, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text.rich(TextSpan(children: [
        TextSpan(text: value == null ? '–' : v.toStringAsFixed(0), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: color)),
        if (value != null) const TextSpan(text: '%', style: TextStyle(fontSize: 12, color: Bz.muted, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 6),
      Container(
        height: 4,
        decoration: BoxDecoration(color: Bz.track, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (v / 100).clamp(0.02, 1),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        ),
      ),
    ]);
  }
}
