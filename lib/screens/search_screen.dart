import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:async';

import '../services/audio_service.dart';
import '../widgets/track_list_item.dart';

class SearchScreen extends StatefulWidget {
  final AudioService audioService;
  final List<SongModel> allSongs;
  final VoidCallback onClose;

  const SearchScreen({
    super.key,
    required this.audioService,
    required this.allSongs,
    required this.onClose,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  List<SongModel> _filteredSongs = [];
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Uses a debounce timer to avoid filtering on every single key press
  void _updateSearch(String newQuery) {
    _searchQuery = newQuery;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filteredSongs = widget.audioService.filterSongs(widget.allSongs, _searchQuery);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _updateSearch,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search songs or artists...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClose, // Use the provided callback to exit search
          ),
        ],
      ),

      body: _searchQuery.isEmpty
          ? Center(
        child: Text(
          'Type to start searching.',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.white54),
        ),
      )
          : _filteredSongs.isEmpty
          ? Center(
        child: Text(
          'No results for "$_searchQuery"',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.white54),
        ),
      )
          : ListView.builder(
        // Extra padding for MiniPlayer visibility
        padding: const EdgeInsets.only(bottom: 160.0),
        itemCount: _filteredSongs.length,
        itemBuilder: (context, index) {
          final song = _filteredSongs[index];
          return TrackListItem(
            audioService: widget.audioService,
            // Play from the filtered search results
            songs: _filteredSongs,
            song: song,
            index: index,
          );
        },
      ),
    );
  }
}