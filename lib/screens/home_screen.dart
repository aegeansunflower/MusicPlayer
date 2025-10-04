import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
    // CRITICAL: Padding must account for the NEW MiniPlayer (~90) + Nav Bar (~60).
    // Adjusted from 130.0 to 160.0 to ensure the track list scrolls fully above the fixed bottom bar area.
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

// -----------------------------------------------------------------
// --- Custom Bottom Navigation Row (Fixed Height) ---
// -----------------------------------------------------------------
class _CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const _CustomNavigationBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final bool isSelected = index == selectedIndex;
    final Color selectedColor = Theme.of(context).primaryColor;
    final Color color = isSelected ? selectedColor : Colors.white54;

    return Expanded(
      child: GestureDetector(
        onTap: () => onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine height for bottom safe area padding
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      // Fixed height for the navigation icons row + bottom padding
      height: 60 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(context, 0, Icons.home_filled, 'HOME'),
          _buildNavItem(context, 1, Icons.search, 'SEARCH'),
          _buildNavItem(context, 2, Icons.favorite, 'FAVORITES'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// --- Main Home Screen with Navigation ---
// -----------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService audioService = AudioService();
  int _selectedIndex = 0; // 0: Home, 1: Search, 2: Favorites
  SongSortMode _sortMode = SongSortMode.title; // Default sort mode
  final ScrollController _scrollController = ScrollController();


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Scroll to top when switching to Home or Favorites
    if (index != 1 && _scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ⭐️ Sort Dialog Method
  void _showSortModeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort Music By'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(context, SongSortMode.title, 'Title (A-Z)'),
              _buildSortOption(context, SongSortMode.recentlyAdded, 'Recently Added'),
              _buildSortOption(context, SongSortMode.durationLongest, 'Duration (Longest First)'),
              _buildSortOption(context, SongSortMode.durationShortest, 'Duration (Shortest First)'),
            ],
          ),
        );
      },
    );
  }

  // Helper for building sort option ListTiles
  Widget _buildSortOption(BuildContext context, SongSortMode mode, String title) {
    final bool isSelected = _sortMode == mode;
    return ListTile(
      title: Text(title),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        setState(() {
          _sortMode = mode;
        });
        Navigator.of(context).pop();
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SongModel>>(
      future: audioService.getLocalSongs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSongs = snapshot.data ?? [];

        if (allSongs.isEmpty) {
          return const Center(
              child: Text('No songs found or permission denied.',
                  style: TextStyle(color: Colors.white70)));
        }

        // Apply Sorting Logic
        List<SongModel> sortedSongs = List.from(allSongs);

        sortedSongs.sort((a, b) {
          final dateA = a.dateAdded ?? 0;
          final dateB = b.dateAdded ?? 0;
          final durationA = a.duration ?? 0;
          final durationB = b.duration ?? 0;

          switch (_sortMode) {
            case SongSortMode.recentlyAdded:
              return dateB.compareTo(dateA); // Newest first (Descending)
            case SongSortMode.durationLongest:
              return durationB.compareTo(durationA); // Longest first (Descending)
            case SongSortMode.durationShortest:
              return durationA.compareTo(durationB); // Shortest first (Ascending)
            case SongSortMode.title:
            return a.title.compareTo(b.title); // Title A-Z (Ascending)
          }
        });


        // Define the content widgets for the main view
        final List<Widget> widgetOptions = <Widget>[
          // 0: Home/Tracks Screen
          AllTracksScreen(
            audioService: audioService,
            allSongs: sortedSongs, // Pass the sorted list
            scrollController: _scrollController,
          ),

          // 1: Search Screen
          SearchScreen(
            audioService: audioService,
            allSongs: allSongs, // Search works best on the unsorted list
            onClose: () {
              setState(() {
                _selectedIndex = 0; // Go to Home
              });
            },
          ),

          // 2: Favorites Screen
          FavoritesScreen(audioService: audioService),
        ];

        // Get the height of the bottom nav bar for positioning the MiniPlayer
        final bottomNavHeight = MediaQuery.of(context).padding.bottom;
        // MiniPlayer height is now 90.0

        return Scaffold(
          appBar: AppBar(
            title: Text(
                _selectedIndex == 0
                    ? 'Local Music'
                    : _selectedIndex == 2
                    ? 'Your Favorites'
                    : 'Search',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28)
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,

            // Filter/Sort Button
            actions: [
              if (_selectedIndex == 0) // Only show on Home Screen
                IconButton(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  onPressed: _showSortModeDialog,
                ),
            ],
          ),

          bottomNavigationBar: _CustomNavigationBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
          ),

          // Body uses a Stack to layer content and the MiniPlayer
          body: Stack(
            children: [
              // 1. Main Content (padded to fit MiniPlayer and Nav Bar)
              Positioned.fill(
                child: widgetOptions.elementAt(_selectedIndex),
              ),

              // 2. MINI PLAYER (Fixed to the bottom, above the Navigation Bar)
              Positioned(
                left: 0,
                right: 0,
                // Positioned right above the bottomNavigationBar
                bottom: bottomNavHeight,
                child: MiniPlayer(audioService: audioService),
              ),
            ],
          ),
        );
      },
    );
  }
}