import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  AudioService() {
    _loadFavorites();
  }

  // Query local songs
  Future<List<SongModel>> getLocalSongs() async {
    bool hasPermission = await _audioQuery.permissionsStatus();
    if (!hasPermission) {
      hasPermission = await _audioQuery.permissionsRequest();
    }
    if (hasPermission) {
      return await _audioQuery.querySongs(
        uriType: UriType.EXTERNAL,
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        ignoreCase: true,
      );
    }
    return [];
  }

  List<SongModel> filterSongs(List<SongModel> allSongs, String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return allSongs.where((song) {
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  // Set queue and play songs with MediaItem for notifications
  Future<void> setQueueAndPlay(List<SongModel> songs, int startIndex) async {
    final playlist = songs.map((song) {
      return AudioSource.uri(
        Uri.parse(song.uri!),
        tag: song, // keep the SongModel as tag
      );
    }).toList();

    await player.setAudioSource(
      ConcatenatingAudioSource(children: playlist),
      initialIndex: startIndex,
      initialPosition: Duration.zero,
    );

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

  // Favorites
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    _favoritesController.add(list.map((e) => int.parse(e)).toSet());
  }

  Future<void> _saveFavorites(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.map((e) => e.toString()).toList());
  }

  void toggleFavorite(int songId) {
    final current = _favoritesController.value.toSet();
    if (current.contains(songId)) current.remove(songId);
    else current.add(songId);
    _favoritesController.add(current);
    _saveFavorites(current);
  }
}
