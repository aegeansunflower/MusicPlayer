// lib/widgets/track_list_item.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/audio_service.dart';

class TrackListItem extends StatelessWidget {
  final AudioService audioService;
  final List<SongModel> songs;
  final SongModel song;
  final int index;

  const TrackListItem({
    super.key,
    required this.audioService,
    required this.songs,
    required this.song,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;

    return ListTile(
      // Album Art Placeholder
      leading: QueryArtworkWidget(
        id: song.id,
        type: ArtworkType.AUDIO,
        nullArtworkWidget: Icon(Icons.music_note, color: activeColor),
        artworkBorder: BorderRadius.circular(5.0),
      ),

      // Text widgets
      title: Text(
        song.title,
        style: const TextStyle(color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist ?? 'Unknown Artist',
        style: const TextStyle(color: Colors.white70),
        overflow: TextOverflow.ellipsis,
      ),

      // Favorite Button (Heart icon)
      trailing: StreamBuilder<Set<int>>(
        stream: audioService.favoritesStream,
        builder: (context, snapshot) {
          final isFavorite = snapshot.data?.contains(song.id) ?? false;
          return IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? activeColor : Colors.white54,
            ),
            onPressed: () {
              audioService.toggleFavorite(song.id);
            },
          );
        },
      ),

      onTap: () {
        audioService.setQueueAndPlay(songs, index);
      },
    );
  }
}