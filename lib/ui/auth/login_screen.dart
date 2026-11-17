import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit(AuthService auth) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسمك أولاً');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final err = await auth.signUpWithName(name);
    if (mounted) setState(() { _busy = false; _error = err; });
  }

  Future<void> _editServer(ApiService api) async {
    final ctrl = TextEditingController(text: api.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'broker.hivemq.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      await api.setBaseUrl(url);
      if (mounted) setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final api = context.watch<ApiService>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('MEZOX MUSIC',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('اكتب اسمك واعمل Sign up',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _editServer(api),
                  child: Text('Relay: ${api.baseUrl} (tap to change)',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    hintText: 'مثال: Olivia',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(auth),
                ),
                const SizedBox(height: 10),
                const Text(
                  'الاسم ده هيكون اسم الحساب. استخدمه عشان تضيف أصحابك وتعمل Listen Together عبر الإنترنت بدون أي سيرفر خاص.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(auth),
                  child: Text(_busy ? 'Please wait...' : 'Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
