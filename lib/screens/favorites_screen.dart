import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/audio_service.dart';
import '../widgets/track_list_item.dart';

class FavoritesScreen extends StatelessWidget {
  final AudioService audioService;

  const FavoritesScreen({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<int>>(
      stream: audioService.favoritesStream,
      builder: (context, snapshot) {
        final favoriteIds = snapshot.data ?? {};

        if (favoriteIds.isEmpty) {
          return Center(
            child: Text(
              'No favorite songs yet.',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.white54),
            ),
          );
        }

        // Filter all local songs down to only favorites
        final allSongs = audioService.getLocalSongs();

        return FutureBuilder<List<SongModel>>(
          future: allSongs,
          builder: (context, songSnapshot) {
            if (songSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final favoriteSongs = songSnapshot.data
                ?.where((song) => favoriteIds.contains(song.id))
                .toList() ?? [];

            return ListView.builder(
              // CRITICAL: Padding for the bottom bar
              padding: const EdgeInsets.only(bottom: 150.0),
              itemCount: favoriteSongs.length,
              itemBuilder: (context, index) {
                final song = favoriteSongs[index];
                return TrackListItem(
                  audioService: audioService,
                  // Play only the favorite songs from the filtered list
                  songs: favoriteSongs,
                  song: song,
                  index: index,
                );
              },
            );
          },
        );
      },
    );
  }
}