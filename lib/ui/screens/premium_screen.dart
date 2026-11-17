import 'package:flutter/material.dart';

import '../../theme/m_theme.dart';

/// Premium promotional page. The Continue actions are live and report that
/// checkout is a future feature instead of dead-ending on an inert button.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const List<_Plan> _plans = <_Plan>[
    _Plan(
      name: 'Listener',
      price: 'Free',
      tagline: 'Everything you already love about M MUSIC.',
      perks: <String>[
        'Unlimited YouTube-powered playback',
        'Playlists, liked songs and history',
        'Lyrics and Listen Together',
      ],
      featured: false,
    ),
    _Plan(
      name: 'Premium',
      price: '\$4.99 / month',
      tagline: 'The full M MUSIC experience, turned all the way up.',
      perks: <String>[
        'Ad-free, uninterrupted listening',
        'Lossless-quality audio streams',
        'Offline downloads on every device',
        'Unlimited skips and queue control',
        'Exclusive visualizer themes',
      ],
      featured: true,
    ),
    _Plan(
      name: 'Premium Plus',
      price: '\$9.99 / month',
      tagline: 'For the listeners who share everything.',
      perks: <String>[
        'Everything in Premium',
        'Six accounts under one plan',
        'High-resolution lossless audio',
        'Priority Listen Together rooms',
        'Early access to new M MUSIC features',
      ],
      featured: false,
    ),
  ];

  void _continue(BuildContext context) {
    MToast.show(context, 'M MUSIC Premium checkout is a future feature — coming soon.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
          glow: true,
          child: Column(
            children: const [
              MLogo(size: 64),
              SizedBox(height: 16),
              Text(
                'M MUSIC PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Turn the volume up on everything. No interruptions, no limits — just the music.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Choose your plan'),
        const SizedBox(height: 12),
        for (final plan in _plans)
          GlassPanel(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            glow: plan.featured,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (plan.featured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: MColors.redGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'MOST POPULAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.price,
                  style: const TextStyle(
                    color: MColors.bright,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.tagline,
                  style: const TextStyle(color: MColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final perk in plan.perks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: MColors.bright, size: 15),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            perk,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: GlowButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    filled: plan.featured,
                    compact: true,
                    onPressed: () => _continue(context),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const Text(
          'M MUSIC — Listen. Enjoy. Repeat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.tagline,
    required this.perks,
    required this.featured,
  });

  final String name;
  final String price;
  final String tagline;
  final List<String> perks;
  final bool featured;
}
