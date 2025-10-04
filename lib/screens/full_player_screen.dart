import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import '../services/audio_service.dart';
import '../widgets/spinning_album_art.dart';
import 'dart:ui' as ui;

// Helper for duration formatting (Full screen version includes hours if needed)
String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return d.toString().split('.').first.padLeft(8, "0");
  } else {
    return d.toString().substring(2, 7);
  }
}

// Helper method to determine the Repeat icon
Widget _buildRepeatIcon(LoopMode mode) {
  final Color color = (mode != LoopMode.off) ? Colors.white : Colors.white54;
  IconData icon;
  switch (mode) {
    case LoopMode.off:
    case LoopMode.all:
      icon = Icons.repeat;
      break;
    case LoopMode.one:
      icon = Icons.repeat_one;
      break;
  }
  return Icon(icon, color: color, size: 36);
}

// The main Full Player Screen widget
class FullPlayerScreen extends StatelessWidget {
  final AudioService audioService;
  final SongModel metadata;

  const FullPlayerScreen({
    super.key,
    required this.audioService,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        // Background color for the whole screen
        color: Theme.of(context).scaffoldBackgroundColor,
        child: StreamBuilder<SequenceState?>(
          stream: audioService.sequenceStateStream,
          builder: (context, snapshot) {
            // Check if audio is currently playing and extract metadata
            final SongModel? currentMetadata = snapshot.data?.currentSource?.tag as SongModel?;

            // Fallback: If currentMetadata is null, show the metadata we passed in.
            final displayMetadata = currentMetadata ?? metadata;

            return SingleChildScrollView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppBar().preferredSize.height),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // 1. Animated Album Art
                    SpinningAlbumArt(
                      metadata: displayMetadata,
                      playerStateStream: audioService.playerStateStream,
                      primaryColor: primaryColor,
                    ),

                    const SizedBox(height: 32),

                    // 2. Song Details (Title and Artist)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayMetadata.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          displayMetadata.artist ?? 'Unknown Artist',
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: primaryColor,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 3. Seek Bar
                    StreamBuilder<PositionData>(
                      stream: audioService.positionDataStream,
                      builder: (context, positionSnapshot) {
                        final positionData = positionSnapshot.data;
                        final position = positionData?.position ?? Duration.zero;
                        final duration = positionData?.duration ?? Duration.zero;

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: duration.inMilliseconds.toDouble(),
                                value: position.inMilliseconds.toDouble().clamp(
                                    0.0, duration.inMilliseconds.toDouble()),
                                activeColor: primaryColor,
                                inactiveColor: Colors.white38,
                                onChanged: (double value) {
                                  audioService.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 4. Playback Controls Row
                    StreamBuilder<PlayerState>(
                      stream: audioService.playerStateStream,
                      builder: (context, playerSnapshot) {
                        final isPlaying = playerSnapshot.data?.playing ?? false;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // 1. Shuffle Button
                            StreamBuilder<bool>(
                              stream: audioService.shuffleModeEnabledStream,
                              builder: (context, snapshot) {
                                final isShuffled = snapshot.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: isShuffled ? Colors.white : Colors.white54,
                                    size: 36,
                                  ),
                                  onPressed: audioService.toggleShuffle,
                                );
                              },
                            ),

                            // 2. Previous Button
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: Colors.white, size: 48),
                              onPressed: audioService.previous,
                            ),

                            // 3. Play/Pause Button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                onPressed: isPlaying ? audioService.pause : audioService.resume,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),

                            // 4. Next Button
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Colors.white, size: 48),
                              onPressed: audioService.next,
                            ),

                            // 5. Repeat Button
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
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // 5. Favorite Button
                    StreamBuilder<Set<int>>(
                      stream: audioService.favoritesStream,
                      builder: (context, snapshot) {
                        final isFavorite = snapshot.data?.contains(displayMetadata.id) ?? false;
                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? primaryColor : Colors.white54,
                            size: 30,
                          ),
                          onPressed: () {
                            audioService.toggleFavorite(displayMetadata.id);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}