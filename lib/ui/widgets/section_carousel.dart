import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/m_theme.dart';
import 'music_card.dart';

class SectionCarousel extends StatelessWidget {
  const SectionCarousel({
    super.key,
    required this.title,
    required this.tracks,
    required this.onPlay,
    this.onMore,
    this.subtitle,
    this.loading = false,
  });

  final String title;
  final List<Track> tracks;
  final void Function(Track) onPlay;
  final void Function(Track)? onMore;
  final String? subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        const SizedBox(height: 12),
        SizedBox(
          height: 238,
          child: loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => GlassPanel(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: 152,
                      height: 198,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : tracks.isEmpty
                  ? Center(
                      child: Text(
                        subtitle ?? 'No tracks available right now.',
                        style: const TextStyle(color: MColors.muted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final t = tracks[i];
                        return MusicCard(
                          track: t,
                          subtitle: subtitle,
                          onPlay: () => onPlay(t),
                          onMore: onMore == null ? null : () => onMore!(t),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
