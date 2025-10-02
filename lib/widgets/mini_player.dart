import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../screens/full_player_screen.dart';

// Helper method to show quick feedback (kept outside the class)
void _showFavoriteSnackbar(BuildContext context, bool isFavorite) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(isFavorite ? 'Removed from Favorites' : 'Added to Favorites'),
      duration: const Duration(milliseconds: 800),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
    ),
  );
}

// Helper method to determine the Repeat icon
Widget _buildRepeatIcon(LoopMode mode) {
  final Color color = (mode != LoopMode.off) ? Colors.white : Colors.white54;
  switch (mode) {
    case LoopMode.off:
    case LoopMode.all:
      return Icon(Icons.repeat, color: color, size: 20); // Smallest size
    case LoopMode.one:
      return Icon(Icons.repeat_one, color: color, size: 20); // Smallest size
  }
}

// 1. Main control row container
class _MiniPlayerContainer extends StatelessWidget {
  final Widget child;
  final Color primaryColor;

  const _MiniPlayerContainer({required this.child, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: child,
    );
  }
}

// 2. Widget that displays Album Art, Title, and Artist
class _TrackInfo extends StatelessWidget {
  final SongModel? metadata;
  const _TrackInfo({this.metadata});

  @override
  Widget build(BuildContext context) {
    final title = metadata?.title ?? 'No Track Loaded';
    final artist = metadata?.artist ?? ' ';
    final activeColor = Theme.of(context).primaryColor;

    return Expanded(
      // Flex reduced to 3 to make room for 5 control buttons
      flex: 3,
      child: Row(
        children: [
          // Album Art Placeholder (44x44)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 44,
              height: 44,
              child: QueryArtworkWidget(
                id: metadata?.id ?? -1,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Icon(
                  Icons.music_note,
                  color: activeColor,
                  size: 24,
                ),
                artworkBorder: BorderRadius.circular(4.0),
                artworkFit: BoxFit.cover,
              ),
            ),
          ),

          // Song Title and Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Playback controls (Shuffle / Previous / Play-Pause / Next / Repeat)
class _PlaybackControls extends StatelessWidget {
  final AudioService audioService;
  final bool isPlaying;

  const _PlaybackControls({
    required this.audioService,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      // Flex 5 for the 5 buttons
      flex: 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Shuffle Button
          StreamBuilder<bool>(
            stream: audioService.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final isShuffleEnabled = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: isShuffleEnabled ? Colors.white : Colors.white54,
                  size: 20,
                ),
                onPressed: audioService.toggleShuffle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            },
          ),

          // 2. Previous Button
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
            onPressed: audioService.previous,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 3. Play/Pause Button (Main Action)
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 40,
            ),
            onPressed: isPlaying ? audioService.pause : audioService.resume,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 4. Next Button
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
            onPressed: audioService.next,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 5. Repeat Button
          StreamBuilder<LoopMode>(
            stream: audioService.loopModeStream,
            builder: (context, snapshot) {
              final loopMode = snapshot.data ?? LoopMode.off;
              return IconButton(
                icon: _buildRepeatIcon(loopMode),
                onPressed: audioService.toggleRepeat,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 4. Main MiniPlayer widget
class MiniPlayer extends StatelessWidget {
  final AudioService audioService;

  const MiniPlayer({super.key, required this.audioService});

  // Handler for favoriting (used by both long-press and double-tap)
  void _toggleFavorite(BuildContext context, SongModel? metadata, Set<int> favoriteIds) {
    if (metadata != null) {
      final bool wasFavorite = favoriteIds.contains(metadata.id);

      audioService.toggleFavorite(metadata.id);

      _showFavoriteSnackbar(context, !wasFavorite);
    }
  }

  // Handler for opening the Full Player
  void _openFullPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullPlayerScreen(audioService: audioService),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;

    return StreamBuilder<Set<int>>(
      stream: audioService.favoritesStream, // Listen to favorite changes
      builder: (context, favoritesSnapshot) {
        final favoriteIds = favoritesSnapshot.data ?? {};

        return StreamBuilder<SequenceState?>(
          stream: audioService.sequenceStateStream,
          builder: (context, sequenceSnapshot) {
            final metadata = sequenceSnapshot.data?.currentSource?.tag as SongModel?;

            if (metadata == null) {
              return const SizedBox.shrink();
            }

            // Use GestureDetector for tap, double-tap, and long-press
            return GestureDetector(
              // 1. OPEN FULL PLAYER (on single tap)
              onTap: () => _openFullPlayer(context),

              // 2. TOGGLE FAVORITE (on double tap)
              onDoubleTap: () => _toggleFavorite(context, metadata, favoriteIds),

              // 3. TOGGLE FAVORITE (on long press - kept for flexibility)
              onLongPress: () => _toggleFavorite(context, metadata, favoriteIds),

              child: _MiniPlayerContainer(
                primaryColor: activeColor,
                child: Row(
                  children: [
                    // Track Info, Album Art, and Song Details
                    _TrackInfo(metadata: metadata),

                    // Playback Controls (5 buttons)
                    StreamBuilder<PlayerState>(
                      stream: audioService.playerStateStream,
                      builder: (context, playerSnapshot) {
                        final isPlaying = playerSnapshot.data?.playing ?? false;
                        return _PlaybackControls(
                          audioService: audioService,
                          isPlaying: isPlaying,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}