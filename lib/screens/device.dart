import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
import 'stat_chart.dart';

class DeviceScreen extends StatefulWidget {
  final BeszelSystem system;
  const DeviceScreen({super.key, required this.system});
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  AlertRules? _r;
  StatRange _range = StatRange.h1;
  List<StatPoint>? _points;
  String? _chartError;

  StreamSubscription<StatPoint>? _live;
  Timer? _liveTimeout;

  @override
  void dispose() {
    _live?.cancel();
    _liveTimeout?.cancel();
    super.dispose();
  }

  Future<void> _startLive() async {
    try {
      var api = await Store.api();
      final pts = <StatPoint>[];
      _liveTimeout = Timer(const Duration(seconds: 10), () {
        if (mounted && pts.isEmpty) setState(() => _chartError = 'Nessun dato live. Serve un agent Beszel 0.13+ e il dispositivo online.');
      });
      _live = api!.realtime(widget.system.id).listen(
        (p) {
          pts.add(p);
          if (pts.length > 60) pts.removeAt(0);
          if (mounted) setState(() { _points = List.of(pts); _chartError = null; });
        },
        onError: (e) { if (mounted) setState(() => _chartError = e.toString()); },
      );
    } catch (e) {
      if (mounted) setState(() => _chartError = e.toString());
    }
  }

  Future<void> _loadStats() async {
    await _live?.cancel();
    _live = null;
    _liveTimeout?.cancel();
    _chartError = null;
    if (_range == StatRange.live) return _startLive();
    try {
      var api = await Store.api();
      List<StatPoint> pts;
      try {
        pts = await api!.stats(widget.system.id, _range);
      } on ApiException catch (e) {
        if (e.status != 401 && e.status != 403) rethrow;
        api = await Store.api(forceLogin: true);
        pts = await api!.stats(widget.system.id, _range);
      }
      if (mounted) setState(() { _points = pts; _chartError = null; });
    } catch (e) {
      if (mounted) setState(() => _chartError = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    Store.range().then((r) {
      setState(() => _range = r);
      _loadStats();
    });
    Store.rules().then((all) => setState(() => _r = all[widget.system.id] ?? AlertRules()));
  }

  Future<void> _save() async {
    final all = await Store.rules();
    all[widget.system.id] = _r!;
    await Store.saveRules(all);
  }

  void _update(VoidCallback f) {
    setState(f);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final s = widget.system;
    return Scaffold(
      appBar: AppBar(title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: AmbientBackground(child: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final r in StatRange.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r == StatRange.live ? '● ${r.label}' : r.label),
                          selected: _range == r,
                          onSelected: (_) {
                            setState(() { _range = r; _points = null; });
                            Store.saveRange(r);
                            _loadStats();
                          },
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 14),
                if (_chartError != null)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_chartError!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                else if (_points == null)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
                else ...[
                  StatChart(title: 'CPU', unit: '%', points: _points!, range: _range, fixedMax: 100, series: [ChartSeries('', Bz.accent, (p) => p.cpu)]),
                  StatChart(title: 'Memoria', unit: '%', points: _points!, range: _range, fixedMax: 100, series: [ChartSeries('', Bz.green, (p) => p.mem)]),
                  StatChart(title: 'Disco', unit: '%', points: _points!, range: _range, fixedMax: 100, series: [ChartSeries('', Bz.orange, (p) => p.disk)]),
                  StatChart(title: 'Rete (MB/s)', unit: '', points: _points!, range: _range, series: [
                    ChartSeries('↑', Bz.purple, (p) => p.netUp),
                    ChartSeries('↓', Bz.teal, (p) => p.netDown),
                  ]),
                ],
                const SizedBox(height: 12),
                Text('Notificami quando…', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _Tile(
                  icon: Icons.power_settings_new,
                  title: 'Il dispositivo va offline',
                  child: Switch(value: r.down, onChanged: (v) => _update(() => r.down = v)),
                ),
                _Threshold(icon: Icons.memory, title: 'CPU sopra', unit: '%', current: s.cpu, value: r.cpu, def: 80, min: 10, max: 100, onChanged: (v) => _update(() => r.cpu = v)),
                _Threshold(icon: Icons.developer_board, title: 'RAM sopra', unit: '%', current: s.mem, value: r.mem, def: 85, min: 10, max: 100, onChanged: (v) => _update(() => r.mem = v)),
                _Threshold(icon: Icons.storage, title: 'Disco sopra', unit: '%', current: s.disk, value: r.disk, def: 90, min: 10, max: 100, onChanged: (v) => _update(() => r.disk = v)),
                _Threshold(icon: Icons.thermostat, title: 'Temperatura sopra', unit: '°C', current: s.temp, value: r.temp, def: 75, min: 30, max: 110, onChanged: (v) => _update(() => r.temp = v)),
                const SizedBox(height: 12),
                Text(
                  'Le notifiche arrivano ogni ~15 minuti con l\'app chiusa (limite di Android) e ogni 20 secondi con l\'app aperta.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            )),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? bottom;
  const _Tile({required this.icon, required this.title, required this.child, this.bottom});

  @override
  Widget build(BuildContext context) {
    return BzCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      child: Column(children: [
          Row(children: [
            Icon(icon, color: Bz.accent),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
            child,
          ]),
          if (bottom != null) bottom!,
        ]),
    );
  }
}

class _Threshold extends StatelessWidget {
  final IconData icon;
  final String title, unit;
  final double? current, value;
  final double def, min, max;
  final ValueChanged<double?> onChanged;
  const _Threshold({required this.icon, required this.title, required this.unit, required this.current, required this.value, required this.def, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    return _Tile(
      icon: icon,
      title: on ? '$title ${value!.round()}$unit' : title,
      child: Switch(value: on, onChanged: (v) => onChanged(v ? def : null)),
      bottom: on
          ? Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(children: [
                Expanded(child: Slider(value: value!.clamp(min, max), min: min, max: max, divisions: (max - min).round(), onChanged: onChanged)),
                Text(current == null ? 'ora –' : 'ora ${current!.round()}$unit', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            )
          : null,
    );
  }
}
