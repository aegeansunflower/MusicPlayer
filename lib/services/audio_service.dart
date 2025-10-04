import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: This enum is used by AudioService for sorting and is often placed
// in a shared utility file or home_screen.dart, but is defined here for completeness.
enum SongSortMode {
  title,
  recentlyAdded,
  durationLongest,
  durationShortest,
}

// PositionData class to track seek/progress
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioService {
  final AudioPlayer player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Public method to allow seeking
  Future<void> seek(Duration position) async => player.seek(position);

  // --- Permission Method ---
  /// Uses the on_audio_query library to check and request Storage permission.
  Future<bool> requestPermission() async {
    return _audioQuery.checkAndRequest(retryRequest: true);
  }
  // -------------------------

  // Favorites persistence
  static const _favoritesKey = 'favorite_song_ids';
  final BehaviorSubject<Set<int>> _favoritesController = BehaviorSubject.seeded({});
  Stream<Set<int>> get favoritesStream => _favoritesController.stream;

  // Player streams
  Stream<SequenceState?> get sequenceStateStream => player.sequenceStateStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<bool> get shuffleModeEnabledStream => player.shuffleModeEnabledStream;
  Stream<LoopMode> get loopModeStream => player.loopModeStream;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          player.positionStream,
          player.bufferedPositionStream,
          player.durationStream,
              (position, buffered, duration) =>
              PositionData(position, buffered, duration ?? Duration.zero));

  // Constructor/Initialization
  AudioService() {
    _loadFavorites();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Allows background playback (optional, but good practice)
    await player.setAudioSource(
      ConcatenatingAudioSource(children: []),
      preload: false,
    );
  }

  // --- Song Query and Filtering ---

  /// Retrieves a list of all local songs from the device storage.
  Future<List<SongModel>> getLocalSongs({SongSortMode? sortMode}) async {
    // OnAudioQuery.querySongs returns all songs in a Future<List<SongModel>>
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE, // Default to title
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Apply custom sorting logic based on the user's choice
    if (sortMode != null) {
      return sortSongs(songs, sortMode);
    }

    return songs;
  }

  /// Sorts a list of songs based on the user-selected mode.
  List<SongModel> sortSongs(List<SongModel> songs, SongSortMode sortMode) {
    switch (sortMode) {
      case SongSortMode.recentlyAdded:
      // Sort by date added, newest first (DESC)
        songs.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case SongSortMode.durationLongest:
      // Sort by duration, longest first (DESC)
        songs.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SongSortMode.durationShortest:
      // Sort by duration, shortest first (ASC)
        songs.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
        break;
      case SongSortMode.title:
      default:
      // Sort by title, A-Z (ASC)
        songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return songs;
  }

  /// Filters a list of songs by title or artist using a search query.
  List<SongModel> filterSongs(List<SongModel> songs, String query) {
    final lowerQuery = query.toLowerCase();
    return songs.where((song) {
      final title = song.title.toLowerCase();
      final artist = song.artist?.toLowerCase() ?? '';
      return title.contains(lowerQuery) || artist.contains(lowerQuery);
    }).toList();
  }

  // --- Playback Controls ---

  /// Plays a list of songs starting at the given index.
  Future<void> play(List<SongModel> songs, {int index = 0}) async {
    // 1. Map SongModels to AudioSources
    final audioSources = songs
        .where((song) => song.uri != null)
        .map((song) => AudioSource.uri(
      Uri.parse(song.uri!),
      tag: song, // Attach the full SongModel as metadata
    ))
        .toList();

    // 2. Set the new playlist
    await player.setAudioSource(
      ConcatenatingAudioSource(children: audioSources),
      initialIndex: index,
      initialPosition: Duration.zero,
      preload: true, // Preload the current item
    );

    // 3. Begin playback
    await player.setShuffleModeEnabled(false);
    await player.play();
  }

  Future<void> pause() async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> next() async => player.seekToNext();
  Future<void> previous() async => player.seekToPrevious();


  // Shuffle & repeat
  Future<void> toggleShuffle() async {
    final enabled = player.shuffleModeEnabled;
    await player.setShuffleModeEnabled(!enabled);
    if (!enabled) await player.shuffle();
  }

  Future<void> toggleRepeat() async {
    final mode = player.loopMode;
    if (mode == LoopMode.off) await player.setLoopMode(LoopMode.all);
    else if (mode == LoopMode.all) await player.setLoopMode(LoopMode.one);
    else await player.setLoopMode(LoopMode.off);
  }
  void dispose() {
    _favoritesController.close();
    // It's generally safer to let the parent widget manage the AudioPlayer disposal,
    // but if the service is a singleton, closing it here is essential.
    // Assuming the player is meant to live longer, we'll only close the stream controllers.
    // If the player needs to be closed, uncomment the line below:
    // player.dispose();
  }
  // --- Favorites Persistence ---

  // Private method: Loads favorites on startup.
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    _favoritesController.add(list.map((e) => int.parse(e)).toSet());
  }

  Future<void> _saveFavorites(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.map((e) => e.toString()).toList());
  }

  bool isFavorite(int songId) {
    return _favoritesController.value.contains(songId);
  }

  Future<void> toggleFavorite(int songId) async {
    final currentFavorites = _favoritesController.value;
    final newFavorites = Set<int>.from(currentFavorites);

    if (newFavorites.contains(songId)) {
      newFavorites.remove(songId);
    } else {
      newFavorites.add(songId);
    }

    _favoritesController.add(newFavorites);
    await _saveFavorites(newFavorites);
  }
}