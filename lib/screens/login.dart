import 'package:flutter/material.dart';
import '../api.dart';
import '../monitor.dart';
import '../storage.dart';
import '../theme.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    if (_url.text.trim().isEmpty || _email.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'Compila tutti i campi');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = normalizeUrl(_url.text);
      final api = BeszelApi(url);
      final token = await api.login(_email.text.trim(), _pw.text);
      await Store.saveSession(url, _email.text.trim(), _pw.text, token);
      await requestNotificationPermission();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: AmbientBackground(child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.monitor_heart_rounded, size: 64, color: Bz.accent),
                  const SizedBox(height: 16),
                  Text('Beszel', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Connettiti al tuo hub', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Indirizzo hub', hintText: '100.64.0.1:8090', prefixIcon: Icon(Icons.dns_outlined)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    onSubmitted: (_) => _connect(),
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Connetti'),
                  ),
                  const SizedBox(height: 14),
                  Text('Sono supportati anche indirizzi http:// (es. Tailscale).', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}
