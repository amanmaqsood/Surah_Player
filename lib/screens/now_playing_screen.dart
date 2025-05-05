// lib/screens/now_playing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_audio_player/services/audio_player_service.dart';
import 'dart:math'; // Keep for potential future animation

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  // ... (_formatDuration helper remains the same)
   String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Define specific colors for this screen
    const Color screenBackground = Color(0xFFFADADD); // Pinkish background
    const Color vinylLabelColor = screenBackground; // Label matches background
    const Color darkTextColor = Colors.black87;
    final Color primaryColor = Theme.of(context).colorScheme.primary; // From theme
    final Color subtitleColor = Colors.grey[700]!; // Darker grey for subtitle

    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        final currentSurah = audioService.currentSurah;
        // ... (get other state variables: isPlaying, processingState, etc.) ...
        final isPlaying = audioService.isPlaying;
        final processingState = audioService.processingState;
        final currentPosition = audioService.currentPosition;
        final totalDuration = audioService.totalDuration;
        final bufferedPosition = audioService.bufferedPosition;
        final isShuffleOn = audioService.isShuffleModeEnabled;
        final repeatMode = audioService.repeatMode;


        if (currentSurah == null) {
          // ... (keep existing null handling, ensure background matches)
          return Scaffold(
            backgroundColor: screenBackground, // Use correct background
            appBar: AppBar( /* ... use black icons/text ... */ ),
            body: const Center(child: Text('No Surah selected')),
          );
        }

        return Scaffold(
          // Apply specific background color for this screen
          backgroundColor: screenBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent, // Theme sets this, but be explicit
            elevation: 0,
            leading: IconButton(
              // Use black icon per screenshot
              icon: const Icon(Icons.expand_more, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Now Playing',
              // Use black bold text per screenshot
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                // Pass label color to vinyl builder
                _buildVinylPlayer(context, isPlaying, vinylLabelColor),
                const SizedBox(height: 40),
                Text(
                  currentSurah.name,
                  // Use dark bold text
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: darkTextColor),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  currentSurah.reciter,
                  // Use specific grey text color
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                _buildProgressBar(context, currentPosition, bufferedPosition, totalDuration, audioService),
                const SizedBox(height: 20),
                _buildPlaybackControls(context, audioService, isPlaying, processingState),
                const SizedBox(height: 20),
                _buildBottomControls(context, audioService, isShuffleOn, repeatMode),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  // Updated Vinyl Player to accept label color
  Widget _buildVinylPlayer(BuildContext context, bool isPlaying, Color labelColor) {
     return Container(
         // ... (size, outer decoration remain the same) ...
         width: MediaQuery.of(context).size.width * 0.7,
         height: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration( /* ... black circle, shadow ... */
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5), ), ],
          ),
         child: Stack(
           alignment: Alignment.center,
           children: [
             Container(
               margin: const EdgeInsets.all(15),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 // Use slightly darker grey for grooves
                 border: Border.all(color: Colors.grey[850]!, width: 15),
               ),
             ),
             // Center Label using passed color
             Container(
               width: MediaQuery.of(context).size.width * 0.25,
               height: MediaQuery.of(context).size.width * 0.25,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: labelColor, // Use passed label color
               ),
               child: Icon(
                 Icons.music_note, // Music note icon
                 color: Colors.black, // Black icon color
                 size: MediaQuery.of(context).size.width * 0.12,
               ),
             ),
           ],
         ),
     );
  }

  Widget _buildProgressBar(
     BuildContext context,
     Duration currentPosition,
     Duration bufferedPosition,
     Duration totalDuration,
     AudioPlayerService audioService) {

     final primaryColor = Theme.of(context).colorScheme.primary;
     final inactiveColor = Colors.grey[300]!; // Lighter grey for inactive track

     // Use specific colors matching the screenshot's progress bar
     return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         SliderTheme(
           // Apply slider theme overrides for exact look
           data: Theme.of(context).sliderTheme.copyWith(
                trackHeight: 4.0,
                // Active track uses primary Red/Pink
                activeTrackColor: primaryColor,
                 // Inactive track is light grey
                inactiveTrackColor: inactiveColor,
                // Thumb uses primary Red/Pink
                thumbColor: primaryColor,
                 // Set overlay color
                overlayColor: primaryColor.withOpacity(0.2),
                // Make buffer visible subtly if needed, or rely on inactive track
                // secondaryActiveTrackColor: primaryColor.withOpacity(0.5), // Optional buffer vis
                trackShape: const RectangularSliderTrackShape(), // Ensure rectangular track
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0), // Adjust thumb size
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0), // Adjust overlay size
           ),
           child: Slider(
             value: currentPosition.inMilliseconds.toDouble().clamp(0.0, totalDuration.inMilliseconds.toDouble()),
             min: 0.0,
             max: totalDuration.inMilliseconds.toDouble(),
             onChanged: (value) {
               final position = Duration(milliseconds: value.toInt());
               audioService.seek(position);
             },
           ),
         ),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               // Use dark text for times
               Text(_formatDuration(currentPosition), style: const TextStyle(fontSize: 12, color: Colors.black87)),
               Text(_formatDuration(totalDuration), style: const TextStyle(fontSize: 12, color: Colors.black87)),
             ],
           ),
         ),
       ],
     );
   }


  Widget _buildPlaybackControls(
      BuildContext context,
      AudioPlayerService audioService,
      bool isPlaying,
      ProcessingState processingState) {

    final primaryColor = Theme.of(context).colorScheme.primary;
    // Use dark grey for prev/next icons when active
    final activeIconColor = Colors.grey[800]; // Darker grey
    final disabledIconColor = Colors.grey.withOpacity(0.4);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.skip_previous,
            color: audioService.hasPrevious ? activeIconColor : disabledIconColor,
          ),
          iconSize: 40.0,
          onPressed: audioService.hasPrevious ? audioService.playPrevious : null,
        ),
        const SizedBox(width: 24),
        if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering)
          Container(
            margin: const EdgeInsets.all(8.0), // Keep margin for spacing consistency
            width: 64.0, height: 64.0,
            child: CircularProgressIndicator(color: primaryColor), // Use primary color
          )
        else
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
            iconSize: 64.0, // Larger size for play/pause
            color: primaryColor, // Use primary color
            onPressed: () {
              if (isPlaying) { audioService.pause(); }
              else { audioService.play(); }
            },
          ),
        const SizedBox(width: 24),
        IconButton(
          icon: Icon(
            Icons.skip_next,
            color: audioService.hasNext ? activeIconColor : disabledIconColor,
          ),
          iconSize: 40.0,
          onPressed: audioService.hasNext ? audioService.playNext : null,
        ),
      ],
    );
  }

  Widget _buildBottomControls(
      BuildContext context,
      AudioPlayerService audioService,
      bool isShuffleOn,
      RepeatMode repeatMode
      ) {

    final primaryColor = Theme.of(context).colorScheme.primary;
    // Use dark grey for inactive bottom icons
    final inactiveIconColor = Colors.grey[700]!;

    IconData repeatIcon;
    Color repeatColor = inactiveIconColor;
    switch (repeatMode) {
      case RepeatMode.off: repeatIcon = Icons.repeat; break;
      case RepeatMode.all: repeatIcon = Icons.repeat; repeatColor = primaryColor; break;
      case RepeatMode.one: repeatIcon = Icons.repeat_one; repeatColor = primaryColor; break;
    }

    Color shuffleColor = isShuffleOn ? primaryColor : inactiveIconColor;
    // TODO: Add favorite state check
    bool isFavorite = false; // Placeholder
    Color favoriteColor = isFavorite ? primaryColor : inactiveIconColor;
    IconData favoriteIcon = isFavorite ? Icons.favorite : Icons.favorite_border;


    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle, color: shuffleColor),
          onPressed: audioService.toggleShuffleMode,
        ),
        IconButton(
          icon: Icon(repeatIcon, color: repeatColor),
          onPressed: audioService.cycleRepeatMode,
        ),
        IconButton(
          icon: Icon(favoriteIcon, color: favoriteColor),
          onPressed: () { print("Favorite Tapped"); /* TODO */ },
        ),
        IconButton(
          // Use share_outlined icon
          icon: Icon(Icons.share_outlined, color: inactiveIconColor),
          onPressed: () { print("Share Tapped"); /* TODO */ },
        ),
      ],
    );
  }
} // End class