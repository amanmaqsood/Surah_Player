// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_audio_player/models/surah.dart';
import 'package:quran_audio_player/services/audio_player_service.dart';
import 'package:quran_audio_player/services/storage_service.dart'; // Import StorageService
import 'package:quran_audio_player/screens/now_playing_screen.dart'; // Ensure NowPlayingScreen is imported
import 'package:share_plus/share_plus.dart'; // Ensure this import is present

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Surah> _surahList = []; // Master list
  List<Surah> _filteredSurahList = []; // List displayed
  bool _isLoading = true;
  final String _audioUrlBase = 'https://server11.mp3quran.net/yasser';
  final String _reciterName = 'Yasser Al-Dosari';
  final TextEditingController _searchController = TextEditingController();

  // --- Add StorageService instance ---
  final StorageService _storageService = StorageService();
  // --- State for Filters ---
  bool _isShowingRecents = false;
  bool _isShowingFavorites = false;
  List<int> _recentSurahNumbers = [];
  List<int> _favoriteSurahNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadSurahData();
    _searchController.addListener(_updateDisplayedList); // Listener handles all updates
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateDisplayedList);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahData() async {
    try {
      final String response = await rootBundle.loadString('assets/surah_data.json');
      final List<dynamic> data = json.decode(response);
      final loadedSurahs = data.map((json) => Surah.fromJson(json, _audioUrlBase, _reciterName)).toList();
      if (mounted) {
        setState(() {
          _surahList = loadedSurahs;
          _filteredSurahList = loadedSurahs; // Initialize filtered list
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading Surah data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Combined Update Logic ---
  void _updateDisplayedList() {
    if (!mounted) return;
    // Apply the currently active filter
    if (_isShowingRecents) { _applyRecentFilter(); }
    else if (_isShowingFavorites) { _applyFavoriteFilter(); }
    else { _applySearchFilter(); }
    // No need to call setState here as it's called by the filter functions or the calling functions (_showRecents etc.)
  }

  void _applySearchFilter() {
    final query = _searchController.text.toLowerCase().trim();
    if (!mounted) return;
    // We need setState here because this is called directly by the listener
    setState(() {
      if (query.isEmpty) {
        _filteredSurahList = _surahList;
      } else {
        _filteredSurahList = _surahList.where((surah) {
          final nameLower = surah.name.toLowerCase();
          final englishNameLower = surah.englishName.toLowerCase();
          final numberString = surah.number.toString();
          return nameLower.contains(query) ||
                 englishNameLower.contains(query) ||
                 numberString.contains(query);
        }).toList();
      }
    });
  }

   void _applyRecentFilter() {
      if (!mounted) return;
       // This function is now only called within setState in _showRecents, so no extra setState needed
      if (_recentSurahNumbers.isEmpty) {
          _filteredSurahList = [];
      } else {
          final Map<int, Surah> surahMap = {for (var s in _surahList) s.number: s};
          _filteredSurahList = _recentSurahNumbers
              .map((number) => surahMap[number])
              .where((surah) => surah != null)
              .cast<Surah>()
              .toList();
      }
  }

  void _applyFavoriteFilter() {
      if (!mounted) return;
       // This function is now only called within setState in _showFavorites
      if (_favoriteSurahNumbers.isEmpty) {
          _filteredSurahList = [];
      } else {
          final Map<int, Surah> surahMap = {for (var s in _surahList) s.number: s};
          _filteredSurahList = _favoriteSurahNumbers
              .map((number) => surahMap[number])
              .where((surah) => surah != null)
              .cast<Surah>()
              .toList();
      }
  }

  // --- Logic to show Recents ---
  Future<void> _showRecents() async {
     _searchController.clear();
     _favoriteSurahNumbers = [];
     _recentSurahNumbers = await _storageService.getRecentSurahNumbers();
     if (!mounted) return;
     setState(() { // Set state *before* applying filter
        _isShowingRecents = true;
        _isShowingFavorites = false;
        _applyRecentFilter(); // Apply filter within setState
     });
  }

  // --- Logic to show Favorites ---
  Future<void> _showFavorites() async {
     _searchController.clear();
     _recentSurahNumbers = [];
     _favoriteSurahNumbers = await _storageService.getFavoriteSurahNumbers();
      if (!mounted) return;
      setState(() { // Set state *before* applying filter
         _isShowingFavorites = true;
         _isShowingRecents = false;
         _applyFavoriteFilter(); // Apply filter within setState
      });
  }

  // --- Logic to show all Surahs ---
  void _showAllSurahs() {
     _searchController.clear();
     if (!mounted) return;
     setState(() {
        _isShowingRecents = false;
        _isShowingFavorites = false;
        _filteredSurahList = _surahList; // Reset to full list
     });
  }

  // --- Widget Build Methods ---

  Widget _buildSearchBar() {
    bool isFilterActive = _isShowingRecents || _isShowingFavorites;
    bool showClearIcon = _searchController.text.isNotEmpty || isFilterActive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        controller: _searchController,
        readOnly: isFilterActive, // Make read-only if showing filter view
        decoration: InputDecoration(
          hintText: 'Search Surahs...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: showClearIcon
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey[600],
                  onPressed: _showAllSurahs, // Always revert to all view
                )
              : null,
        ),
        onTap: isFilterActive ? _showAllSurahs : null, // Tap search bar cancels filter view
      ),
    );
  }

  Widget _buildTopNavigation() {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(context, Icons.history, 'Recent', _showRecents),
          _buildNavIcon(context, Icons.favorite_border, 'Favorite', _showFavorites),
          _buildNavIcon(context, Icons.equalizer, 'Playback', () {
            if (audioService.currentSurah != null) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NowPlayingScreen()));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing is playing'), duration: Duration(seconds: 1)));
            }
          }),
          _buildNavIcon(context, Icons.download_outlined, 'Download', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloads: Not Implemented'), duration: Duration(seconds: 1)));
          }),
        ],
      ),
    );
  }

  Widget _buildNavIcon(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    final iconColor = Theme.of(context).iconTheme.color;
    final textColor = Colors.grey[700];
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    String emptyMessage = "No Surahs found.";
    if (_isShowingRecents && _filteredSurahList.isEmpty) emptyMessage = "No recently played Surahs.";
    if (_isShowingFavorites && _filteredSurahList.isEmpty) emptyMessage = "No favorite Surahs yet.";

    if (_filteredSurahList.isEmpty && !_isLoading) {
       return Expanded(child: Center(child: Text(emptyMessage)));
    }

    final listIconColor = Theme.of(context).colorScheme.secondary;
    final subtitleColor = Colors.grey[600];

    return Expanded(
      child: ListView.separated(
        itemCount: _filteredSurahList.length,
        itemBuilder: (context, index) {
          final surah = _filteredSurahList[index];
          return ListTile(
            leading: Icon(Icons.music_note, color: listIconColor),
            title: Text(surah.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(surah.reciter, style: TextStyle(color: subtitleColor, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showSurahOptions(context, surah),
            ),
            onTap: () {
              final audioService = Provider.of<AudioPlayerService>(context, listen: false);
              final originalIndex = _surahList.indexWhere((s) => s.number == surah.number);
              if (originalIndex != -1) {
                audioService.loadPlaylist(_surahList, initialIndex: originalIndex);
                // Optional: Switch back to all view after selection
                // if (_isShowingRecents || _isShowingFavorites) { _showAllSurahs(); }
              } else {
                print("Error: Could not find original index for ${surah.name}");
              }
            },
          );
        },
        separatorBuilder: (context, index) => Divider(height: 1, thickness: 0.5, color: Colors.grey[200], indent: 70, endIndent: 16),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        final currentSurah = audioService.currentSurah;
        if (currentSurah == null) {
          return const SizedBox.shrink();
        }

        final currentPosition = audioService.currentPosition;
        final totalDuration = audioService.totalDuration;
        final double progressValue = totalDuration.inMilliseconds > 0
            ? currentPosition.inMilliseconds.toDouble().clamp(0.0, totalDuration.inMilliseconds.toDouble())
            : 0.0;
        final double maxDuration = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;

        final primaryColor = Theme.of(context).colorScheme.primary;
        final secondaryColor = Theme.of(context).colorScheme.secondary;
        final backgroundColor = Theme.of(context).colorScheme.background;
        final subtitleColor = Colors.grey[600];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
            );
          },
          child: Material(
            elevation: 6.0,
            color: backgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    height: 10,
                    child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0, pressedElevation: 0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                            activeTrackColor: primaryColor,
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: primaryColor,
                            overlayColor: primaryColor.withOpacity(0.2),
                            trackShape: const RectangularSliderTrackShape(),
                            minThumbSeparation: 0,
                        ),
                        child: Slider(
                            value: progressValue,
                            min: 0.0,
                            max: maxDuration,
                            onChanged: (value) {
                                final position = Duration(milliseconds: value.toInt());
                                audioService.seek(position);
                            },
                        ),
                    ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                      children: [
                          Icon(Icons.music_note, color: secondaryColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                  Text(currentSurah.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                  Text(currentSurah.reciter, style: TextStyle(fontSize: 12, color: subtitleColor), overflow: TextOverflow.ellipsis),
                              ],),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                              icon: Icon(audioService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: primaryColor, size: 40.0),
                              onPressed: () { if (audioService.isPlaying) { audioService.pause(); } else { audioService.play(); } },
                          ),
                      ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSurahOptions(BuildContext context, Surah surah) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext bc) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Wrap(
            children: <Widget>[
              ListTile(leading: const Icon(Icons.playlist_add), title: const Text('Add to Playlist'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add ${surah.name} to Playlist (Not implemented)'), duration: const Duration(seconds: 1)),); }),
              ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Download'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download ${surah.name} (Not implemented)'), duration: const Duration(seconds: 1)),); }),
              ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share'), onTap: () { Navigator.pop(context); _shareSurah(surah); }),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Show Details for ${surah.name} (Not implemented)'), duration: const Duration(seconds: 1)),); }),
            ],
          ),
        );
      },
    );
  }

  void _shareSurah(Surah surah) async {
    final textToShare = 'Listen to ${surah.name} recited by ${surah.reciter}:\n${surah.audioUrl}';
    try {
      await Share.share(textToShare, subject: 'Listen to ${surah.name}');
    } catch (e) {
      print("Error sharing: $e");
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not initiate sharing.'), duration: Duration(seconds: 1)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? title; // Optional title
    if (_isShowingRecents) title = "Recently Played";
    if (_isShowingFavorites) title = "Favorites";

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Conditional Title Row or Search Bar ---
            if (title != null)
               Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 8.0),
                  child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                     Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     TextButton( onPressed: _showAllSurahs, child: const Text("SHOW ALL") ),
                  ]),
               )
            else // Show search bar if no title
               _buildSearchBar(),

            _buildTopNavigation(),
            Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
            _buildSurahList(),
            _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }
} // End _HomeScreenState