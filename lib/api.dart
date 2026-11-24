import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Accepts "100.64.0.1:8090", "http://host:8090/" etc. Defaults to http://.
String normalizeUrl(String input) {
  var u = input.trim();
  if (!u.contains('://')) u = 'http://$u';
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

class BeszelApi {
  final String baseUrl;
  String? token;
  BeszelApi(this.baseUrl, {this.token});

  static const _timeout = Duration(seconds: 12);

  Future<String> login(String email, String password) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/collections/users/auth-with-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identity': email, 'password': password}),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) {
        throw ApiException(r.statusCode == 400 ? 'Credenziali non valide' : 'Errore server (${r.statusCode})', r.statusCode);
      }
      token = jsonDecode(r.body)['token'] as String;
      return token!;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Impossibile raggiungere il server');
    }
  }

  Future<List<BeszelSystem>> systems() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/collections/systems/records?perPage=200&sort=name'),
        headers: {'Authorization': token ?? ''},
      ).timeout(_timeout);
      if (r.statusCode != 200) throw ApiException('Errore server (${r.statusCode})', r.statusCode);
      final items = jsonDecode(r.body)['items'] as List;
      return items.map((e) => BeszelSystem.fromJson(Map<String, dynamic>.from(e))).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Impossibile raggiungere il server');
    }
  }

  Future<List<StatPoint>> stats(String systemId, StatRange range) async {
    try {
      final uri = Uri.parse('$baseUrl/api/collections/system_stats/records').replace(queryParameters: {
        'filter': "system='$systemId' && type='${range.type}'",
        'sort': '-created',
        'perPage': '${range.points}',
        'fields': 'created,stats',
      });
      final r = await http.get(uri, headers: {'Authorization': token ?? ''}).timeout(_timeout);
      if (r.statusCode != 200) throw ApiException('Errore server (${r.statusCode})', r.statusCode);
      final items = jsonDecode(r.body)['items'] as List;
      return items.map((e) => StatPoint.fromJson(Map<String, dynamic>.from(e))).toList().reversed.toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Impossibile caricare i grafici');
    }
  }

  /// Live metrics (~1 point/second) via PocketBase realtime SSE, topic `rt_metrics`.
  /// Needs a Beszel agent >= 0.13. Cancel the subscription to stop.
  Stream<StatPoint> realtime(String systemId) async* {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse('$baseUrl/api/realtime'))
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Authorization'] = token ?? '';
      final resp = await client.send(req).timeout(_timeout);
      if (resp.statusCode != 200) throw ApiException('Errore server (${resp.statusCode})', resp.statusCode);
      var event = '';
      await for (final line in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (event == 'PB_CONNECT') {
            final clientId = jsonDecode(data)['clientId'] as String;
            final opts = Uri.encodeComponent(jsonEncode({'query': {'system': systemId}}));
            await http.post(
              Uri.parse('$baseUrl/api/realtime'),
              headers: {'Content-Type': 'application/json', 'Authorization': token ?? ''},
              body: jsonEncode({'clientId': clientId, 'subscriptions': ['rt_metrics?options=$opts']}),
            ).timeout(_timeout);
          } else if (event.startsWith('rt_metrics')) {
            yield StatPoint.fromStats(DateTime.now(), jsonDecode(data)['stats']);
          }
        } else if (line.isEmpty) {
          event = '';
        }
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connessione live non riuscita');
    } finally {
      client.close();
    }
  }
}
