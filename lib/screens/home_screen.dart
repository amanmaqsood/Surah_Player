// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_audio_player/models/surah.dart';
import 'package:quran_audio_player/services/audio_player_service.dart';
import 'package:quran_audio_player/screens/now_playing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Surah> _surahList = [];
  bool _isLoading = true;
  final String _audioUrlBase = 'https://server11.mp3quran.net/yasser';
  final String _reciterName = 'Yasser Al-Dosari';

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  Future<void> _loadSurahData() async {
    // ... (keep existing load logic)
     try {
          final String response = await rootBundle.loadString('assets/surah_data.json');
          final List<dynamic> data = json.decode(response);
          setState(() {
            _surahList = data.map((json) => Surah.fromJson(json, _audioUrlBase, _reciterName)).toList();
            _isLoading = false;
          });
        } catch (e) {
          print("Error loading Surah data: $e");
          setState(() {
            _isLoading = false;
          });
        }
  }

  // --- Widget Build Methods ---

  Widget _buildSearchBar() {
    // Using InputDecorationTheme from main.dart now
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...', // Match hint text
          prefixIcon: const Icon(Icons.search), // Icon color from theme
          // Other properties like fillColor, border are set by theme
        ),
        // TODO: Add onChanged for search functionality
      ),
    );
  }

  Widget _buildTopNavigation() {
    // Use correct icons and themed colors
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(Icons.history, 'Recent', () => print("Recent Tapped")),
          _buildNavIcon(Icons.favorite_border, 'Favorite', () => print("Favorite Tapped")),
          // Use equalizer icon to match screenshot
          _buildNavIcon(Icons.equalizer, 'Playback', () => print("Playback Tapped")),
          _buildNavIcon(Icons.download_outlined, 'Download', () => print("Download Tapped")),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, VoidCallback onPressed) {
    final iconColor = Theme.of(context).iconTheme.color; // Use default icon grey
    final textColor = Colors.grey[700]; // Explicit grey for text

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor), // Use themed color
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    if (_surahList.isEmpty) {
      return const Expanded(child: Center(child: Text("Failed to load Surahs.")));
    }

    // Use secondary color for list icon
    final listIconColor = Theme.of(context).colorScheme.secondary;
    final subtitleColor = Colors.grey[600]; // Specific grey for subtitle

    return Expanded(
      child: ListView.separated( // Use separated for dividers
        itemCount: _surahList.length,
        itemBuilder: (context, index) {
          final surah = _surahList[index];
          return ListTile(
             // Leading icon matching screenshot
            leading: Icon(Icons.music_note, color: listIconColor),
            title: Text(
                surah.name,
                // Make title slightly bolder if needed
                style: const TextStyle(fontWeight: FontWeight.w500) // Medium weight
                ),
            subtitle: Text(
                surah.reciter,
                style: TextStyle(color: subtitleColor, fontSize: 12) // Match style
                ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert), // Icon color from theme (grey)
              onPressed: () { print("Options for ${surah.name} tapped"); },
            ),
            onTap: () {
              final audioService = Provider.of<AudioPlayerService>(context, listen: false);
              audioService.loadPlaylist(_surahList, initialIndex: index);
            },
          );
        },
         separatorBuilder: (context, index) => Divider( // Add subtle divider
             height: 1,
             thickness: 0.5,
             color: Colors.grey[200],
             indent: 70, // Indent past the icon area
             endIndent: 16,
         ),
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
        final double progress = (totalDuration.inMilliseconds > 0)
            ? (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        // Use theme colors
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
            elevation: 6.0, // Adjust elevation for shadow
            // Ensure background matches the page background
            color: backgroundColor,
            // Clip shadow if needed, but usually not necessary for bottom element
            // clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Progress Bar ---
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor), // Use primary color
                  minHeight: 2.5,
                ),
                // --- Content Row ---
                Padding( // Use Padding instead of Container for simplicity
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // Icon matching list items
                      Icon(Icons.music_note, color: secondaryColor, size: 28), // Use secondary color
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentSurah.name,
                              style: const TextStyle(fontWeight: FontWeight.w500), // Match list title weight
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentSurah.reciter,
                              style: TextStyle(fontSize: 12, color: subtitleColor), // Match list subtitle style
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Play/Pause button
                      IconButton(
                        icon: Icon(
                          audioService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: primaryColor, // Use primary color
                          size: 40.0, // Match size in screenshot
                        ),
                        onPressed: () {
                          if (audioService.isPlaying) {
                            audioService.pause();
                          } else {
                            audioService.play();
                          }
                        },
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

  // --- Main build method ---
  @override
  Widget build(BuildContext context) {
    // Scaffold background color is set by the theme
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildTopNavigation(),
            // Use a lighter divider or remove if not desired
             Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
            _buildSurahList(),
            _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }
}