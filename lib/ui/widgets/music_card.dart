import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/m_theme.dart';

/// Glass card used in home, explore, discovery and library grids.
class MusicCard extends StatelessWidget {
  const MusicCard({
    super.key,
    required this.track,
    required this.onPlay,
    this.onMore,
    this.width = 172,
    this.subtitle,
    this.heroTag,
  });

  final Track track;
  final VoidCallback onPlay;
  final VoidCallback? onMore;
  final double width;
  final String? subtitle;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ?? track.artist;
    Widget image = Hero(
      tag: heroTag ?? 'art-${track.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: track.artworkUrl.isEmpty
            ? Container(
                color: MColors.darkRed,
                child: const Icon(Icons.music_note, color: Colors.white, size: 40),
              )
            : Image.network(
                track.artworkUrl,
                width: width - 20,
                height: width - 20,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: MColors.surface,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                        color: MColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: MColors.darkRed,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.white70),
                ),
              ),
      ),
    );

    return GlassPanel(
      onTap: onPlay,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(right: 14, bottom: 6),
      radius: 18,
      child: SizedBox(
        width: width - 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                image,
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlay,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: MColors.redGradient,
                          boxShadow: [
                            BoxShadow(color: MColors.primary.withOpacity(0.6), blurRadius: 16),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                ),
                if (onMore != null)
                  InkWell(
                    onTap: onMore,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.more_vert, color: MColors.muted, size: 17),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
