import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../../theme/m_theme.dart';

String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0
      ? '${d.inHours}:$m:$s'
      : '$m:$s';
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onPlay,
    this.onMore,
    this.highlight = false,
    this.trailing,
    this.index,
  });

  final Track track;
  final VoidCallback onPlay;
  final VoidCallback? onMore;
  final bool highlight;
  final Widget? trailing;
  final int? index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? MColors.primary.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? Border.all(color: MColors.primary.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            if (index != null) ...[
              SizedBox(
                width: 22,
                child: Text(
                  '${index! + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: highlight ? MColors.bright : MColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.artworkUrl.isEmpty
                  ? Container(
                      width: 46,
                      height: 46,
                      color: MColors.darkRed,
                      child: const Icon(Icons.music_note, color: Colors.white70),
                    )
                  : Image.network(
                      track.artworkUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 46,
                        color: MColors.darkRed,
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlight ? MColors.bright : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (track.duration != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  formatDuration(track.duration),
                  style: const TextStyle(color: MColors.muted, fontSize: 11),
                ),
              ),
            if (trailing != null) trailing!,
            if (onMore != null)
              InkWell(
                onTap: onMore,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert, color: MColors.muted, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
