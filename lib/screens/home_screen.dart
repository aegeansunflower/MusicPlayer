import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/audio_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list_item.dart';
import 'search_screen.dart';
import 'favorites_screen.dart'; // Required for the Favorites tab


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
    // CRITICAL: Large padding at the bottom (MiniPlayer + Nav Row)
    // The total height of the bottom bar (MiniPlayer 60 + Nav Row 60) is 120, plus safety margin.
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 150.0),
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
// --- Custom Bottom Bar Widget (MiniPlayer + Nav Row) ---
// -----------------------------------------------------------------
class _CustomBottomBar extends StatelessWidget {
  final AudioService audioService;
  final int selectedIndex;
  final Function(int) onItemTapped;

  const _CustomBottomBar({
    required this.audioService,
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
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(audioService: audioService),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20), // increased from 6 to 12 to lift
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(context, 0, Icons.home_filled, 'HOME'),
                _buildNavItem(context, 1, Icons.search, 'SEARCH'),
                _buildNavItem(context, 2, Icons.favorite, 'FAVORITES'),
              ],
            ),
          ),
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
  int _selectedIndex = 0; // 0: Home, 1: Search (Trigger), 2: Favorites
  bool _isSearching = false;
  final ScrollController _scrollController = ScrollController();


  void _onItemTapped(int index) {
    if (index == 1) { // Search button
      setState(() {
        _isSearching = true;
      });
    } else {
      setState(() {
        _selectedIndex = index;
        _isSearching = false; // Close search if navigating away
      });
      // Scroll to top when switching tabs
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
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

        // Define the content widgets for the main view
        final List<Widget> widgetOptions = <Widget>[
          // 0: Home/Tracks Screen
          AllTracksScreen(
            audioService: audioService,
            allSongs: allSongs,
            scrollController: _scrollController,
          ),

          // 1: Placeholder (Search is handled by the overlay)
          Container(),

          // 2: Favorites Screen
          FavoritesScreen(audioService: audioService),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
                _selectedIndex == 0 ? 'Local Music' : 'Your Favorites',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28)
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),

          // Body uses a Stack to layer content and the search overlay
          body: Stack(
            children: [
              // Show the current screen content (Home or Favorites)
              widgetOptions.elementAt(_isSearching ? 0 : _selectedIndex),

              // Search overlay on top when active
              if (_isSearching)
                SearchScreen(
                  audioService: audioService,
                  allSongs: allSongs,
                  onClose: () {
                    setState(() {
                      _isSearching = false;
                      _selectedIndex = 0; // Revert to Home view
                    });
                  },
                ),
            ],
          ),

          bottomSheet: _CustomBottomBar(
            audioService: audioService,
            selectedIndex: _isSearching ? 1 : _selectedIndex,
            onItemTapped: _onItemTapped,
          ),
        );
      },
    );
  }
}