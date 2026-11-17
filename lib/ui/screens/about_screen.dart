import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/m_theme.dart';

/// M MUSIC branding, version, credits and feature list.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<String> _features = <String>[
    'YouTube-powered streaming with direct audio playback',
    'Real-time lyrics that land a few seconds into every track',
    'Listen Together — sync playback with friends in real time',
    'Red & black glass interface with live visualizers',
    'Playlists, liked songs, search and listening history',
    'Fullscreen immersive player and queue management',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
          glow: true,
          child: Column(
            children: const [
              MLogo(size: 76),
              SizedBox(height: 18),
              Text(
                'M MUSIC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Listen. Enjoy. Repeat.',
                style: TextStyle(color: MColors.bright, fontSize: 14, letterSpacing: 1.2),
              ),
              SizedBox(height: 18),
              Chip(
                avatar: Icon(Icons.new_releases_outlined, color: MColors.bright, size: 15),
                label: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                backgroundColor: Color(0x1AFF1028),
                side: BorderSide(color: MColors.glassBorder),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('What M MUSIC does'),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            children: [
              for (final feature in _features)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: MColors.bright, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Credits'),
        const SizedBox(height: 10),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _CreditLine(icon: Icons.developer_mode, label: 'Design & engineering', value: 'olltaterfx'),
              SizedBox(height: 10),
              _CreditLine(icon: Icons.flutter_dash, label: 'Built with', value: 'Flutter & Dart'),
              SizedBox(height: 10),
              _CreditLine(icon: Icons.music_note, label: 'Metadata & playback', value: 'YouTube Data API / IFrame API'),
              SizedBox(height: 10),
              _CreditLine(icon: Icons.favorite_outline, label: 'Made for', value: 'Every listener who hits repeat'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'M MUSIC 1.0.0 — Listen. Enjoy. Repeat.',
                  style: TextStyle(color: MColors.muted, fontSize: 12),
                ),
              ),
              GlowButton(
                label: 'Copy info',
                icon: Icons.copy,
                compact: true,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: 'M MUSIC 1.0.0 — Listen. Enjoy. Repeat.'),
                  );
                  if (context.mounted) MToast.show(context, 'App info copied');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CreditLine extends StatelessWidget {
  const _CreditLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MColors.bright, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: MColors.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
