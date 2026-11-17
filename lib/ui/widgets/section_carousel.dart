import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/m_theme.dart';
import 'music_card.dart';

class SectionCarousel extends StatefulWidget {
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
  State<SectionCarousel> createState() => _SectionCarouselState();
}

class _SectionCarouselState extends State<SectionCarousel> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _scrollable(Widget child) => Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 4,
        radius: const Radius.circular(4),
        interactive: true,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(widget.title),
        const SizedBox(height: 12),
        SizedBox(
          height: 238,
          child: widget.loading
              ? _scrollable(
                  ListView.separated(
                    controller: _controller,
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
                  ),
                )
              : widget.tracks.isEmpty
                  ? Center(
                      child: Text(
                        widget.subtitle ?? 'No tracks available right now.',
                        style: const TextStyle(color: MColors.muted, fontSize: 12),
                      ),
                    )
                  : _scrollable(
                      ListView.builder(
                        controller: _controller,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.tracks.length,
                        itemBuilder: (_, i) {
                          final t = widget.tracks[i];
                          return MusicCard(
                            track: t,
                            subtitle: widget.subtitle,
                            onPlay: () => widget.onPlay(t),
                            onMore:
                                widget.onMore == null ? null : () => widget.onMore!(t),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
