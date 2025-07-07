import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/constants.dart';
import '../../data/datasources/search/search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Debouncer to limit API calls
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _animationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchCtrl.text.trim().isNotEmpty) {
        _fetchSearchResults();
      } else {
        setState(() {
          _searchResults = [];
          _errorMessage = '';
          _animationController.reverse();
        });
      }
    });
  }

  Future<void> _fetchSearchResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final results = await _searchService.search(_searchCtrl.text.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _animationController.forward();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching results: $e';
        _isLoading = false;
        _animationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Search',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [Colors.white, Colors.greenAccent],
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.grey[850]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, color: Colors.white70, size: 24),
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'songs, artists...',
                hintStyle: TextStyle(color: Colors.white60, fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchResults = [];
                  _errorMessage = '';
                  _animationController.reverse();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_searchCtrl.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search...',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : _errorMessage.isNotEmpty
              ? Center(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
              : _searchResults.isEmpty
              ? const Center(
            child: Text(
              'No results found.',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          )
              : ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              const Text(
                'Top Results',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Songs',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ..._searchResults
                  .where((result) => result.containsKey('title'))
                  .map((song) => _SongResultTile(song: song)),
              const SizedBox(height: 24),
              const Text(
                'Artists',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ..._searchResults
                  .where((result) => result.containsKey('fullName'))
                  .map((artist) => _ArtistResultTile(artist: artist)),
            ],
          ),
        );
      },
    );
  }
}

class _SongResultTile extends StatelessWidget {
  final Map<String, dynamic> song;
  const _SongResultTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            song['coverImagePath'] != null ? '$baseUrl${song['coverImagePath']}' : 'https://via.placeholder.com/40x40',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[800],
              width: 40,
              height: 40,
              child: const Icon(Icons.music_note, color: Colors.white60),
            ),
          ),
        ),
        title: Text(
          song['title'] ?? 'Untitled',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          song['artistName'] ?? 'Unknown Artist',
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              song['duration'] ?? 'N/A',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_circle_fill, color: Colors.green, size: 20),
          ],
        ),
        onTap: () {
          // TODO: Navigate to player screen with this song
        },
      ),
    );
  }
}

class _ArtistResultTile extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistResultTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(
            artist['avatarPath'] != null ? '$baseUrl${artist['avatarPath']}' : 'https://via.placeholder.com/48x48',
          ),
          backgroundColor: Colors.grey[800],
          onBackgroundImageError: (_, __) => const Icon(Icons.person, color: Colors.white60),
        ),
        title: Text(
          artist['fullName'] ?? 'Unknown Artist',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        onTap: () {
          // TODO: Navigate to artist profile
        },
      ),
    );
  }
}