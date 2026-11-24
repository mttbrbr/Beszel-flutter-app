import 'package:flutter/material.dart';
import '../monitor.dart';
import '../theme.dart';
import 'device.dart';

IconData alertIcon(String key) => switch (key) {
      'down' => Icons.power_settings_new,
      'cpu' => Icons.memory,
      'mem' => Icons.developer_board,
      'disk' => Icons.storage,
      _ => Icons.thermostat,
    };

/// Lists every rule that is violated right now.
class AlertsScreen extends StatelessWidget {
  final List<ActiveAlert> alerts;
  const AlertsScreen({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avvisi attivi')),
      body: AmbientBackground(child: alerts.isEmpty
          ? const Center(child: Text('Nessun avviso attivo', style: TextStyle(color: Bz.muted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final a in alerts)
                  BzCard(
                    accent: Bz.red,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceScreen(system: a.system))),
                    child: Row(children: [
                      Icon(alertIcon(a.key), color: Bz.red),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.system.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(a.message, style: const TextStyle(color: Bz.muted, fontSize: 13)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: Bz.muted),
                    ]),
                  ),
              ],
            )),
    );
  }
}
