import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:async';

class SpinningAlbumArt extends StatefulWidget {
  final SongModel? metadata;
  final Stream<PlayerState> playerStateStream;
  final Color primaryColor;

  const SpinningAlbumArt({
    super.key,
    required this.metadata,
    required this.playerStateStream,
    required this.primaryColor,
  });

  @override
  State<SpinningAlbumArt> createState() => _SpinningAlbumArtState();
}

class _SpinningAlbumArtState extends State<SpinningAlbumArt>
    with SingleTickerProviderStateMixin {

  // Animation Controller for the wavy effect
  late AnimationController _controller;

  // Animation for translating the widget (the "wavy" effect)
  late Animation<Offset> _animation;

  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();

    // Controller runs slowly for a subtle effect (20 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    // Animation Tween: defines the slow, floating shift (2% left/right, 2% up/down)
    _animation = Tween<Offset>(
      begin: const Offset(0.02, 0.02), // Start slightly right and down
      end: const Offset(-0.02, -0.02), // End slightly left and up
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Smooth acceleration/deceleration
    ));

    // Start the animation immediately and repeat in reverse for the wavy motion
    _controller.repeat(reverse: true);


    // Subscribe to the stream to manage animation state
    _playerStateSubscription = widget.playerStateStream.listen((state) {
      if (state.playing) {
        // If playing, ensure the animation continues
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        // If paused, stop the animation
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    // Ensure all resources are cleaned up when the widget is closed/disposed
    _playerStateSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Builds the static content (Album Art or Placeholder)
  Widget _buildStaticArt(BuildContext context) {
    // Placeholder widget
    final Widget placeholder = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.music_note,
        size: 100,
        color: widget.primaryColor,
      ),
    );

    // Check if metadata exists
    if (widget.metadata == null) {
      return placeholder;
    }

    // Attempt to load artwork
    return QueryArtworkWidget(
      id: widget.metadata!.id,
      type: ArtworkType.AUDIO,
      nullArtworkWidget: placeholder,
      artworkBorder: BorderRadius.circular(16),
      artworkFit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The SlideTransition applies the horizontal/vertical movement (the "wavy" effect)
    return AspectRatio(
      aspectRatio: 1.0,
      child: SlideTransition( // The Wavy Effect!
        position: _animation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildStaticArt(context),
        ),
      ),
    );
  }
}