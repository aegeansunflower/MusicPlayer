import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import '../services/audio_service.dart';
import 'dart:ui' as ui;

// --- Widget to display the current track's album art ---
class _ArtDisk extends StatefulWidget {
  final SongModel? metadata;
  final AudioService audioService;

  const _ArtDisk({required this.metadata, required this.audioService, Key? key}) : super(key: key);

  @override
  State<_ArtDisk> createState() => _ArtDiskState();
}

class _ArtDiskState extends State<_ArtDisk> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _rainbowController;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    widget.audioService.playerStateStream.listen((state) {
      if (state.playing) {
        _spinController.repeat();
        _rainbowController.repeat();
      } else {
        _spinController.stop();
        _rainbowController.stop();
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _rainbowController.dispose();
    super.dispose();
  }

  Widget _buildArtwork(BuildContext context) {
    if (widget.metadata == null) {
      return const Icon(Icons.music_note, size: 80, color: Colors.white70);
    }

    return QueryArtworkWidget(
      id: widget.metadata!.id,
      type: ArtworkType.AUDIO,
      nullArtworkWidget: Icon(Icons.music_note, size: 80, color: Colors.white),
      artworkBorder: BorderRadius.circular(100),
      artworkFit: BoxFit.cover,
      quality: 100,
      format: ArtworkFormat.PNG,
    );
  }


  Widget _buildSongTitle(String title) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: [
            Colors.purple,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.purple,
            Colors.indigo,
            Colors.purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white, // color will be overridden by shader
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double size = MediaQuery.of(context).size.width * 0.8;
    double artworkSize = size * 0.4;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rainbow glow behind disk
          AnimatedBuilder(
            animation: _rainbowController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rainbowController.value * 2 * math.pi,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.green,
                        Colors.blue,
                        Colors.indigo,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(.5),
                        blurRadius: 100, // slightly reduced blur
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Optional semi-transparent spinning disk on top
          RotationTransition(
            turns: _spinController,
            child: Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.1),
              ),
            ),
          ),

          // Small album art in center
          Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(child: _buildArtwork(context)),
          ),
        ],
      ),
    );
  }
}
// --- Full Player Screen ---
class FullPlayerScreen extends StatelessWidget {
  final AudioService audioService;

  const FullPlayerScreen({super.key, required this.audioService});

  // Helper method to determine the Repeat icon
  Widget _buildRepeatIcon(LoopMode mode) {
    final Color color = (mode != LoopMode.off) ? Colors.white : Colors.white54;
    switch (mode) {
      case LoopMode.off:
      case LoopMode.all:
        return Icon(Icons.repeat, color: color, size: 50);
      case LoopMode.one:
        return Icon(Icons.repeat_one, color: Colors.pink, size: 50);
    }
  }

  // Helper to format Duration into MM:SS
  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '0:00';
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      body: Dismissible(
        key: const Key('fullPlayerDismiss'),
        direction: DismissDirection.down,

        onDismissed: (_) {
          Navigator.pop(context);
        },

        child: SafeArea(
          child: StreamBuilder<SequenceState?>(
            stream: audioService.sequenceStateStream,
            builder: (context, sequenceSnapshot) {
              final metadata = sequenceSnapshot.data?.currentSource?.tag as SongModel?;
              final currentSongId = metadata?.id;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. TOP BAR (Close Button & FAVORITE BUTTON)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dismiss Button (Top Left)
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),

                        // FAVORITE BUTTON (Top Right)
                        StreamBuilder<Set<int>>(
                          stream: audioService.favoritesStream,
                          builder: (context, favoritesSnapshot) {
                            final isFavorite = favoritesSnapshot.data?.contains(currentSongId) ?? false;

                            return InkWell(
                              onTap: currentSongId == null ? null : () => audioService.toggleFavorite(currentSongId),
                              child: ShaderMask(
                                shaderCallback: (bounds) {
                                  return const LinearGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.red,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: Colors.white, // required but overridden by shader
                                  size: 36,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // 2. ALBUM ART DISK
                    _ArtDisk(metadata: metadata, audioService: audioService),

                    // 3. TRACK INFO
                    // 3. TRACK INFO
                    Column(
                      children: [
                        Text(
                          metadata?.title ?? 'Unknown Title',  // <-- This is the song title
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          metadata?.artist ?? 'Unknown Artist', // <-- This is the artist name
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // 4. SEEK BAR
                    StreamBuilder<PositionData>(
                      stream: audioService.positionDataStream,
                      builder: (context, snapshot) {
                        final positionData = snapshot.data ??
                            PositionData(Duration.zero, Duration.zero, Duration.zero);
                        final totalDuration = positionData.duration;

                        return Column(
                          children: [
                            Slider(
                              min: 0.0,
                              max: totalDuration.inMilliseconds.toDouble(),
                              value: math.min(positionData.position.inMilliseconds.toDouble(), totalDuration.inMilliseconds.toDouble()),
                              onChanged: (double value) {
                                audioService.player.seek(Duration(milliseconds: value.round()));
                              },
                              activeColor: Colors.pink,
                              inactiveColor: Colors.white30,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(positionData.position),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    _formatDuration(totalDuration),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // 5. PLAYBACK CONTROLS (5-BUTTON ROW)
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
                                final isShuffleEnabled = snapshot.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: isShuffleEnabled ? Colors.white : Colors.purple,
                                    size: 50,
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

                            // 3. Play/Pause Button (Main Action)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
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
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}