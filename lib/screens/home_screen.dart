import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:async'; // For Future

import '../services/audio_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list_item.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';

// --- ENUM for Sorting Modes ---
enum SongSortMode {
  title, // Default: Sort by Title (A-Z)
  recentlyAdded, // Newest first
  durationLongest, // Longest songs first
  durationShortest, // Shortest songs first
}

// --- A dedicated widget for the main list of all tracks ---
class AllTracksScreen extends StatelessWidget {
  final AudioService audioService;
  final List<SongModel> allSongs;
  final ScrollController scrollController;

  const AllTracksScreen({
    super.key,
    required this.audioService,
    required this.allSongs,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Padding accounts for the MiniPlayer and Nav Bar.
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 160.0),
      itemCount: allSongs.length,
      itemBuilder: (context, index) {
        final song = allSongs[index];
        return TrackListItem(
          audioService: audioService,
          songs: allSongs,
          song: song,
          index: index,
        );
      },
    );
  }
}

// --- Main Screen Widget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AudioService audioService = AudioService();
  SongSortMode _currentSortMode = SongSortMode.title;

  // New: State management for the song list future
  late Future<List<SongModel>> _allSongsFuture; // Keep 'late'
  List<SongModel> _allSongs = [];
  final ScrollController _scrollController = ScrollController();

  // FIX: Initialize the late variable here by calling _loadSongs()
  @override
  void initState() {
    super.initState();
    _loadSongs(); // Call loadSongs immediately to initialize _allSongsFuture
  }

  @override
  void dispose() {
    audioService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // New Method: Loads songs and updates the Future state
  void _loadSongs() {
    // FIX: Assign _allSongsFuture here. Since _loadSongs is called in initState,
    // the Future will be ready before the first build.
    _allSongsFuture = audioService.getLocalSongs().then((songs) {
      // Filter out invalid/unplayable tracks (e.g., duration < 5 seconds)
      _allSongs = songs.where((song) => song.duration != null && song.duration! > 5000).toList();
      _sortSongs(_currentSortMode); // Apply current sort mode after load
      return _allSongs;
    });

    // Call setState to ensure the FutureBuilder runs when the Future is assigned.
    // This is safe even in initState because setState in initState only flags a build.
    if (mounted) {
      setState(() {});
    }
  }

  // New Method: Handles song rescan
  Future<void> _rescanSongs() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rescanning songs...'),
        duration: Duration(seconds: 1),
      ),
    );
    _loadSongs(); // Reruns the song query, which updates _allSongsFuture
  }

  // Existing Method: Sorts the song list based on the current mode
  void _sortSongs(SongSortMode mode) {
    _currentSortMode = mode;

    // NOTE: This sorting should only happen on the internal _allSongs list
    // after the FutureBuilder returns data, or inside _loadSongs().
    switch (mode) {
      case SongSortMode.title:
        _allSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SongSortMode.recentlyAdded:
      // Sort by date added (newest first)
        _allSongs.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case SongSortMode.durationLongest:
      // Sort by duration (longest first)
        _allSongs.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SongSortMode.durationShortest:
      // Sort by duration (shortest first)
        _allSongs.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
        break;
    }

    // Trigger a rebuild only if we are on the main tracks screen
    if (_selectedIndex == 0 && mounted) {
      setState(() {});
    }
  }

  // Existing Method: Shows the sorting dialog
  void _showSortModeDialog() {
    showDialog<SongSortMode>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Sort By', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF282828),
          children: SongSortMode.values.map((mode) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, mode);
              },
              child: Text(
                mode.toString().split('.').last.replaceAllMapped(
                    RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}'),
                style: TextStyle(
                  color: _currentSortMode == mode ? Theme.of(context).primaryColor : Colors.white70,
                ),
              ),
            );
          }).toList(),
        );
      },
    ).then((selectedMode) {
      if (selectedMode != null && selectedMode != _currentSortMode) {
        _sortSongs(selectedMode);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double bottomNavHeight =0;

    // The widget options, now using _allSongs
    final List<Widget> widgetOptions = [
      // 1. All Tracks Screen (Wrapped in FutureBuilder for loading state)
      FutureBuilder<List<SongModel>>(
        // Uses the initialized Future
        future: _allSongsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allSongs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading songs: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }

          final loadedSongs = snapshot.data ?? _allSongs; // Use loaded data or current state
          if (loadedSongs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No songs found.', style: TextStyle(color: Colors.white70)),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rescan Storage'),
                  onPressed: _rescanSongs,
                ),
              ],
            ));
          }

          _allSongs = loadedSongs; // Update the list reference before passing

          return AllTracksScreen(
            audioService: audioService,
            allSongs: _allSongs,
            scrollController: _scrollController,
          );
        },
      ),
      // 2. Search Screen
      SearchScreen(
        audioService: audioService,
        allSongs: _allSongs, // Pass the current state of loaded songs
        onClose: () => _onItemTapped(0),
      ),
      // 3. Favorites Screen
      FavoritesScreen(audioService: audioService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _selectedIndex == 0
                ? 'All Tracks'
                : _selectedIndex == 2
                ? 'Your Favorites'
                : 'Search',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28)
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        actions: [
          if (_selectedIndex == 0) ...[
            // Existing Sort Button
            IconButton(
              icon: const Icon(Icons.sort, color: Colors.white),
              onPressed: _showSortModeDialog,
            ),
            // NEW Rescan Button (to the right of the sort button)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _rescanSongs, // Use the new rescan method
            ),
          ],
        ],
      ),

      bottomNavigationBar: _CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),

      // Body uses a Stack to layer content and the MiniPlayer
      body: Stack(
        children: [
          // 1. Main Content
          Positioned.fill(
            child: widgetOptions.elementAt(_selectedIndex),
          ),

          // 2. MINI PLAYER (Fixed to the bottom, above the Navigation Bar)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomNavHeight,
            child: MiniPlayer(audioService: audioService),
          ),
        ],
      ),
    );
  }
}

// --- Helper Widget for the Bottom Navigation Bar ---
class _CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const _CustomNavigationBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.music_note),
          label: 'Tracks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Favorites',
        ),
      ],
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      backgroundColor: const Color(0xFF181818),
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
    );
  }
}