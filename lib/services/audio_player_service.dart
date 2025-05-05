// lib/services/audio_player_service.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_audio_player/models/surah.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:math'; // Import for Random

// Define RepeatMode enum outside the class for easier access
enum RepeatMode { off, one, all }

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Surah> _originalPlaylist = []; // Keep the original order
  List<Surah> _playbackPlaylist = []; // This list will be shuffled if needed
  List<int> _shuffledIndices = [];    // Store shuffled indices mapping
  int? _currentIndexInPlayback;      // Index in the _playbackPlaylist

  Surah? _currentSurah;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // --- State Variables for Shuffle/Repeat ---
  bool _isShuffleModeEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  final _random = Random(); // For shuffling


  // --- Getters ---
  Surah? get currentSurah => _currentSurah;
  ProcessingState get processingState => _processingState;
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _currentPosition;
  Duration get bufferedPosition => _bufferedPosition;
  Duration get totalDuration => _totalDuration;
  bool get isShuffleModeEnabled => _isShuffleModeEnabled;
  RepeatMode get repeatMode => _repeatMode;

  // Updated logic for hasNext/hasPrevious based on repeat modes
   bool get hasNext {
       if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return false;
       // Always true if repeating all or one
       if (_repeatMode == RepeatMode.all || _repeatMode == RepeatMode.one) return true;
       // Otherwise, check if not at the end
       return _currentIndexInPlayback! < _playbackPlaylist.length - 1;
   }

   bool get hasPrevious {
       if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return false;
       // Always true if repeating all
       if (_repeatMode == RepeatMode.all) return true;
        // If repeating one, maybe false? Or allow restarting? Let's allow restart for now.
       if (_repeatMode == RepeatMode.one) return true;
       // Otherwise, check if not at the beginning
       return _currentIndexInPlayback! > 0;
   }


  AudioPlayerService() {
    _init();
  }

  // --- Playlist Management ---
  Future<void> loadPlaylist(List<Surah> playlist, {int? initialIndex}) async {
    _originalPlaylist = List.from(playlist); // Store original order
    _playbackPlaylist = List.from(playlist); // Start with original order
    _currentIndexInPlayback = null;
    _currentSurah = null;

    // If shuffle is enabled, shuffle immediately
    if (_isShuffleModeEnabled) {
       _shufflePlaylist(keepCurrent: false); // Shuffle the _playbackPlaylist
    } else {
       _shuffledIndices = List.generate(playlist.length, (i) => i); // Reset indices if not shuffling
    }

    await _audioPlayer.stop();
    _processingState = ProcessingState.idle;
    notifyListeners();

    int targetIndex = initialIndex ?? 0; // Default to 0 if null

    // If shuffle is on, we need to find where the originally requested Surah ended up
     if (_isShuffleModeEnabled && initialIndex != null) {
         final originalSurah = _originalPlaylist[initialIndex];
         targetIndex = _playbackPlaylist.indexWhere((s) => s.number == originalSurah.number);
         if (targetIndex == -1) targetIndex = 0; // Fallback if not found (shouldn't happen)
     } else if (initialIndex == null && _isShuffleModeEnabled) {
         targetIndex = 0; // Start at the beginning of the shuffled list if no initial index specified
     }


    if (targetIndex >= 0 && targetIndex < _playbackPlaylist.length) {
      await _loadAndPlayIndex(targetIndex);
    }
  }

   // Internal method to shuffle the _playbackPlaylist
  void _shufflePlaylist({required bool keepCurrent}) {
      if (_originalPlaylist.isEmpty) return;

      Surah? surahToKeep;
      if (keepCurrent && _currentIndexInPlayback != null) {
         surahToKeep = _playbackPlaylist[_currentIndexInPlayback!];
      }

      // Create shuffled list based on original playlist
      _playbackPlaylist = List.from(_originalPlaylist);
      _playbackPlaylist.shuffle(_random);

      // If we need to keep the current track at the current position (index 0 after shuffle)
      if (surahToKeep != null) {
         _playbackPlaylist.removeWhere((s) => s.number == surahToKeep!.number);
         _playbackPlaylist.insert(0, surahToKeep);
         _currentIndexInPlayback = 0; // Current track is now at index 0
      } else {
         // If not keeping current or nothing was playing, reset index
          _currentIndexInPlayback = null; // Will be set when something is played
      }

      // Note: We might need to update _shuffledIndices if we rely on it elsewhere
       _shuffledIndices = _playbackPlaylist.map((surah) =>
          _originalPlaylist.indexWhere((orig) => orig.number == surah.number)).toList();

      print("Playlist shuffled. Current index: $_currentIndexInPlayback");
      notifyListeners(); // Notify that shuffle state changed potentially affecting next/prev
  }


   // In lib/services/audio_player_service.dart

    // Internal method to load and play a specific index in _playbackPlaylist
    Future<void> _loadAndPlayIndex(int index) async {
        if (index < 0 || index >= _playbackPlaylist.length) {
            print("Index out of bounds: $index");
            return;
        }

        // --- ADD STOP BEFORE LOADING NEW TRACK ---
        try {
           await _audioPlayer.stop();
        } catch(e) {
           print("Error stopping player before loading new index: $e");
           // Continue regardless, maybe it wasn't necessary or failed gracefully
        }
        // -----------------------------------------

        _currentIndexInPlayback = index;
        _currentSurah = _playbackPlaylist[index];
        _currentPosition = Duration.zero; // Reset position state
        _bufferedPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _processingState = ProcessingState.loading; // Set loading state
        notifyListeners(); // Notify UI about the new surah being loaded

        try {
            print("Loading Surah [${_currentIndexInPlayback}]: ${_currentSurah!.audioUrl}");
            final source = AudioSource.uri(Uri.parse(_currentSurah!.audioUrl));
            // Ensure initialPosition is set (it was already, but double-checking)
            await _audioPlayer.setAudioSource(source, initialPosition: Duration.zero, preload: true);

            print("Surah loaded successfully: ${_currentSurah!.name}");
            await play(); // Start playback after loading

        } catch (e) {
            print("Error loading audio source at index $index: $e");
            _currentSurah = null;
            _currentIndexInPlayback = null;
            _processingState = ProcessingState.idle;
            notifyListeners();
        }
    }

  // --- Playback Controls ---
  Future<void> play() async {
      // ... (Keep existing audio focus logic) ...
     final session = await AudioSession.instance;
     if (await session.setActive(true)) {
         if (_currentSurah != null && _processingState != ProcessingState.idle) {
             try {
               await _audioPlayer.play();
             } catch (e) {
                print("Error playing audio: $e");
             }
         }
     } else {
       print("Failed to activate audio session");
     }
  }

  Future<void> pause() async {
      // ... (Keep existing pause logic) ...
     try {
        await _audioPlayer.pause();
     } catch (e) {
         print("Error pausing audio: $e");
     }
  }

  Future<void> seek(Duration position) async {
      // ... (Keep existing seek logic) ...
      final targetPosition = position.isNegative
        ? Duration.zero
        : (position > _totalDuration ? _totalDuration : position);

    try {
      await _audioPlayer.seek(targetPosition);
      _currentPosition = targetPosition; // Update UI immediately
      notifyListeners();
    } catch (e) {
       print("Error seeking audio: $e");
    }
  }

  Future<void> playNext() async {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return;

      if (_repeatMode == RepeatMode.one) {
          // If repeating one, just seek to beginning and play again
          seek(Duration.zero);
          play();
          return;
      }

      int nextIndex = _currentIndexInPlayback! + 1;
      if (nextIndex >= _playbackPlaylist.length) {
          if (_repeatMode == RepeatMode.all) {
              // Wrap around to the beginning if repeating all
              nextIndex = 0;
          } else {
              // Stop if not repeating all and reached the end
              print("End of playlist reached.");
              await _audioPlayer.stop();
              _processingState = ProcessingState.completed;
              seek(Duration.zero);
              pause();
              notifyListeners();
              return;
          }
      }
      await _loadAndPlayIndex(nextIndex);
  }

  Future<void> playPrevious() async {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return;

       if (_repeatMode == RepeatMode.one) {
          // If repeating one on Previous, just seek to beginning
          seek(Duration.zero);
          play(); // Start playing from beginning
          return;
      }

      int previousIndex = _currentIndexInPlayback! - 1;
      if (previousIndex < 0) {
         if (_repeatMode == RepeatMode.all) {
             // Wrap around to the end if repeating all
             previousIndex = _playbackPlaylist.length - 1;
         } else {
             // Stop if not repeating all and reached the beginning
             print("Start of playlist reached.");
             await _audioPlayer.stop();
              // Go to idle state rather than completed when stopping at start?
             _processingState = ProcessingState.idle;
             seek(Duration.zero);
             pause();
             notifyListeners();
             return;
         }
      }
      await _loadAndPlayIndex(previousIndex);
  }

   // --- Toggle Methods for Shuffle/Repeat ---
  Future<void> toggleShuffleMode() async {
      _isShuffleModeEnabled = !_isShuffleModeEnabled;
      print("Shuffle mode: $_isShuffleModeEnabled");

      // Re-shuffle or restore original order
      if (_isShuffleModeEnabled) {
          _shufflePlaylist(keepCurrent: true); // Shuffle, keeping current track if playing
      } else {
          // Restore original order, keeping current track at its new position
          Surah? current = _currentSurah;
          _playbackPlaylist = List.from(_originalPlaylist);
          _shuffledIndices = List.generate(_originalPlaylist.length, (i) => i); // Reset indices

          if (current != null) {
              // Find the index of the current surah in the now-unshuffled list
              _currentIndexInPlayback = _playbackPlaylist.indexWhere((s) => s.number == current.number);
              if (_currentIndexInPlayback == -1) _currentIndexInPlayback = null; // Should not happen
          } else {
              _currentIndexInPlayback = null;
          }
      }
      notifyListeners(); // Notify UI of shuffle state change
  }

  Future<void> cycleRepeatMode() async {
      if (_repeatMode == RepeatMode.off) {
          _repeatMode = RepeatMode.all;
      } else if (_repeatMode == RepeatMode.all) {
          _repeatMode = RepeatMode.one;
      } else {
          _repeatMode = RepeatMode.off;
      }
      print("Repeat mode: $_repeatMode");
      // Apply repeat mode to the player if necessary (just_audio handles looping internally)
       _audioPlayer.setLoopMode(
         _repeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off
         // Note: LoopMode.all in just_audio might loop the entire playlist source if set up that way,
         // but we are handling playlist looping manually in playNext/playPrevious for more control.
         // So we only set LoopMode.one here.
       );

      notifyListeners(); // Notify UI of repeat state change
  }


  // --- Initialization and Listeners ---
  Future<void> _init() async {
    // ... (Keep existing session configuration and interruption listeners) ...
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    session.interruptionEventStream.listen((event) { /* ... keep existing logic ... */ });
    session.becomingNoisyEventStream.listen((_) { /* ... keep existing logic ... */ });


    _audioPlayer.playerStateStream.listen((playerState) {
      _processingState = playerState.processingState;

      if (_processingState == ProcessingState.completed) {
        // Handle completion based on repeat mode (playNext already incorporates this)
        if (_repeatMode != RepeatMode.one) {
          // If not repeating one, automatically try to play the next track
          // This includes handling RepeatMode.all wrapping or stopping for RepeatMode.off
          playNext();
        } else {
           // If repeating one, the player's LoopMode.one should handle it automatically.
           // But just in case, we can ensure it restarts.
            seek(Duration.zero);
            play(); // Explicitly play again
        }
      }
      notifyListeners(); // Notify for processing state changes too

    });

    // In lib/services/audio_player_service.dart -> _init() method

    _audioPlayer.positionStream.listen((position) {
        final oldPos = _currentPosition;
        _currentPosition = position;
        // --- REMOVE or COMMENT OUT the threshold check ---
        // if ((_currentPosition - oldPos).abs().inMilliseconds > 200) {
        //    notifyListeners();
        // }
        // --- ALWAYS NOTIFY ---
        // Only notify if position actually changed to avoid unnecessary builds
        // (comparing Duration objects works)
        if (_currentPosition != oldPos) {
             notifyListeners();
        }
    });

    // Also remove threshold from buffered position listener for consistency
    _audioPlayer.bufferedPositionStream.listen((buffered) {
        final oldBuffered = _bufferedPosition;
        _bufferedPosition = buffered;
        // --- REMOVE or COMMENT OUT the threshold check ---
        // if ((_bufferedPosition - oldBuffered).abs().inMilliseconds > 500) {
        //     notifyListeners();
        // }
        // --- ALWAYS NOTIFY ---
        if (_bufferedPosition != oldBuffered) {
             notifyListeners();
        }
    });

    _audioPlayer.durationStream.listen((duration) {
      // ... (keep existing logic) ...
       final oldDuration = _totalDuration;
       _totalDuration = duration ?? Duration.zero;
       if(oldDuration != _totalDuration) {
          notifyListeners();
       }
    });

    _audioPlayer.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
          // ... (keep existing error handling) ...
          print('A stream error occurred: $e');
          _processingState = ProcessingState.idle;
          _currentSurah = null;
          _currentIndexInPlayback = null;
          notifyListeners();
        });
  }

  @override
  void dispose() {
    // ... (Keep existing dispose logic) ...
     AudioSession.instance.then((session) => session.setActive(false));
    _audioPlayer.dispose();
    super.dispose();
  }
}