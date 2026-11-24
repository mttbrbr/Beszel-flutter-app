class BeszelSystem {
  final String id;
  final String name;
  final String host;
  final String status; // up | down | paused | pending
  final double? cpu;
  final double? mem;
  final double? disk;
  final double? temp;

  const BeszelSystem({
    required this.id,
    required this.name,
    required this.host,
    required this.status,
    this.cpu,
    this.mem,
    this.disk,
    this.temp,
  });

  bool get isUp => status == 'up';

  factory BeszelSystem.fromJson(Map<String, dynamic> j) {
    final info = (j['info'] is Map) ? Map<String, dynamic>.from(j['info']) : <String, dynamic>{};
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    return BeszelSystem(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      host: (j['host'] ?? '') as String,
      status: (j['status'] ?? 'pending') as String,
      cpu: n(info['cpu']),
      mem: n(info['mp']),
      disk: n(info['dp']),
      temp: n(info['dt']),
    );
  }
}

/// Alert rules for one device. A null threshold means "disabled".
class AlertRules {
  bool down;
  double? cpu;
  double? mem;
  double? disk;
  double? temp;

  AlertRules({this.down = false, this.cpu, this.mem, this.disk, this.temp});

  bool get any => down || cpu != null || mem != null || disk != null || temp != null;

  Map<String, dynamic> toJson() => {'down': down, 'cpu': cpu, 'mem': mem, 'disk': disk, 'temp': temp};

  factory AlertRules.fromJson(Map<String, dynamic> j) => AlertRules(
        down: j['down'] == true,
        cpu: (j['cpu'] as num?)?.toDouble(),
        mem: (j['mem'] as num?)?.toDouble(),
        disk: (j['disk'] as num?)?.toDouble(),
        temp: (j['temp'] as num?)?.toDouble(),
      );
}

class StatPoint {
  final DateTime time;
  final double? cpu, mem, disk, netUp, netDown; // % and MB/s
  const StatPoint(this.time, {this.cpu, this.mem, this.disk, this.netUp, this.netDown});

  factory StatPoint.fromJson(Map<String, dynamic> j) =>
      StatPoint.fromStats(DateTime.parse((j['created'] as String).replaceFirst(' ', 'T')).toLocal(), j['stats']);

  factory StatPoint.fromStats(DateTime time, dynamic stats) {
    final st = (stats is Map) ? Map<String, dynamic>.from(stats) : <String, dynamic>{};
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    double? up = n(st['ns']), down = n(st['nr']);
    if (up == null && st['b'] is List && (st['b'] as List).length >= 2) {
      up = n(st['b'][0]);
      down = n(st['b'][1]);
      if (up != null) up /= 1048576;
      if (down != null) down /= 1048576;
    }
    return StatPoint(
      time,
      cpu: n(st['cpu']),
      mem: n(st['mp']),
      disk: n(st['dp']),
      netUp: up,
      netDown: down,
    );
  }
}

/// Observation windows, mapped to Beszel's pre-aggregated stat types.
enum StatRange {
  live('1m', 'live', 60),
  h1('1h', '1m', 60),
  h12('12h', '10m', 72),
  h24('24h', '20m', 72),
  d7('7g', '120m', 84),
  d30('30g', '480m', 90);

  final String label, type;
  final int points;
  const StatRange(this.label, this.type, this.points);
}
