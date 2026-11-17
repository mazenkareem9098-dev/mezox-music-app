import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/m_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسمكFirst — enter a name to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final err = await context.read<AuthService>().signUpWithName(name);
      if (err != null && mounted) {
        setState(() => _error = err);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRelay(BuildContext context) async {
    final api = context.read<ApiService>();
    final ctrl = TextEditingController(text: api.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: MColors.primary.withOpacity(0.4)),
        ),
        title: const Text('Public relay', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'broker.hivemq.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: MColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MColors.primary),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await api.setBaseUrl(result.trim());
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    return AnimatedRedBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassPanel(
                radius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
                glow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MLogo(size: 88),
                    const SizedBox(height: 18),
                    const Text(
                      'M MUSIC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'LISTEN. ENJOY. REPEAT.',
                      style: TextStyle(
                        color: MColors.bright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'اكتب اسمك وابدأ — name only, no password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signUp(),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _editRelay(context),
                      child: Text(
                        'Relay: ${api.baseUrl}  (tap to change)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: MColors.bright, fontSize: 11),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: MColors.bright, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GlowButton(
                        label: _busy ? 'Starting...' : 'SIGN UP',
                        icon: Icons.arrow_forward_rounded,
                        filled: true,
                        onPressed: _busy ? () {} : _signUp,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'A new red music experience.',
                      style: TextStyle(color: MColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
