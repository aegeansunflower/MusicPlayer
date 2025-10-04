import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';
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

// Helper for duration formatting
String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return d.toString().split('.').first.padLeft(8, "0");
  } else {
    return d.toString().substring(2, 7);
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
      // Total height: 60 (controls) + 30 (seek bar) = 90
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(1),
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: primaryColor, width: .5),
      ),
      child: child,
    );
  }
}

// 2. Track Info (Album Art and Text)
class _TrackInfo extends StatelessWidget {
  final SongModel? metadata;
  final VoidCallback? onTap;

  const _TrackInfo({required this.metadata, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Album Art Placeholder
            QueryArtworkWidget(
              id: metadata?.id ?? 0,
              type: ArtworkType.AUDIO,
              nullArtworkWidget: Icon(
                Icons.music_note,
                color: primaryColor,
                size: 24,
              ),
              artworkBorder: BorderRadius.circular(8.0),
              size: 48,
              quality: 50,
            ),
            const SizedBox(width: 8),

            // Song Details
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata?.title ?? 'No Song Playing',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    metadata?.artist ?? 'Unknown Artist',
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
      ),
    );
  }
}

// 3. Playback Controls (Previous, Play/Pause, Next)
class _PlaybackControls extends StatelessWidget {
  final AudioService audioService;
  final bool isPlaying;

  const _PlaybackControls({required this.audioService, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Shuffle
        StreamBuilder<bool>(
          stream: audioService.shuffleModeEnabledStream,
          builder: (context, snapshot) {
            final isShuffled = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                Icons.shuffle,
                color: isShuffled ? Colors.white : Colors.white54,
                size: 20,
              ),
              onPressed: audioService.toggleShuffle,
            );
          },
        ),
        // 2. Previous
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
          onPressed: audioService.previous,
        ),
        // 3. Play/Pause
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: Colors.white,
            size: 36,
          ),
          onPressed: isPlaying ? audioService.pause : audioService.resume,
        ),
        // 4. Next
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
          onPressed: audioService.next,
        ),
        // 5. Repeat
        StreamBuilder<LoopMode>(
          stream: audioService.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            return IconButton(
              icon: _buildRepeatIcon(loopMode),
              onPressed: audioService.toggleRepeat,
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// 4. Seek Bar (The thin progress bar)
class _SeekBar extends StatelessWidget {
  final AudioService audioService;
  final Color primaryColor;

  const _SeekBar({required this.audioService, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: audioService.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        final position = positionData?.position ?? Duration.zero;
        final duration = positionData?.duration ?? Duration.zero;

        // Calculate progress percentage
        final progress = duration.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / duration.inMilliseconds;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: SizedBox(
            height: 20, // Reduced height for the mini-player
            child: Row(
              children: [
                // Current Position Text
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                Expanded(
                  // Progress Bar
                  child: Slider(
                    min: 0.0,
                    max: duration.inMilliseconds.toDouble(),
                    value: position.inMilliseconds.toDouble().clamp(
                        0.0, duration.inMilliseconds.toDouble()),
                    activeColor: primaryColor,
                    inactiveColor: Colors.white12,
                    onChanged: (double value) {
                      audioService.seek(Duration(milliseconds: value.toInt()));
                    },
                    thumbColor: primaryColor,
                  ),
                ),
                // Total Duration Text
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 5. The Main MiniPlayer Widget
class MiniPlayer extends StatelessWidget {
  final AudioService audioService;
  const MiniPlayer({super.key, required this.audioService});

  void _openFullPlayer(BuildContext context, SongModel? metadata) {
    if (metadata == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullPlayerScreen(
          audioService: audioService,
          metadata: metadata,
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, SongModel? metadata, Set<int> favoriteIds) {
    if (metadata == null) return;

    final isFavorite = favoriteIds.contains(metadata.id);
    audioService.toggleFavorite(metadata.id);
    _showFavoriteSnackbar(context, isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;

    return StreamBuilder<SequenceState?>(
      stream: audioService.sequenceStateStream,
      builder: (context, sequenceSnapshot) {
        // Get the current song metadata
        final metadata = sequenceSnapshot.data?.currentSource?.tag as SongModel?;

        return StreamBuilder<Set<int>>(
          stream: audioService.favoritesStream,
          builder: (context, favoriteSnapshot) {
            final favoriteIds = favoriteSnapshot.data ?? {};

            // If no metadata, hide the MiniPlayer
            if (metadata == null) {
              return const SizedBox.shrink();
            }

            // Use GestureDetector for tap, double-tap, and long-press
            return GestureDetector(
              // 1. OPEN FULL PLAYER (on single tap)
              onTap: () => _openFullPlayer(context, metadata),

              // 2. TOGGLE FAVORITE (on double tap)
              onDoubleTap: () => _toggleFavorite(context, metadata, favoriteIds),

              // 3. TOGGLE FAVORITE (on long press - kept for flexibility)
              onLongPress: () => _toggleFavorite(context, metadata, favoriteIds),

              child: _MiniPlayerContainer(
                primaryColor: activeColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOP ROW: Track Info and Playback Controls (Height 60)
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          // ⭐️ _TrackInfo handles single tap to open full player
                          _TrackInfo(
                            metadata: metadata,
                            onTap: () => _openFullPlayer(context, metadata),
                          ),

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

                    // BOTTOM ROW: Seek Bar (Now fully responsive to tap-to-seek)
                    _SeekBar(audioService: audioService, primaryColor: activeColor),
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