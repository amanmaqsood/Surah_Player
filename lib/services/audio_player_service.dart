// lib/services/audio_player_service.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_audio_player/models/surah.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:math';
import 'package:quran_audio_player/services/storage_service.dart'; // Import StorageService

// Define RepeatMode enum outside the class for easier access
enum RepeatMode { off, one, all }

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Surah> _originalPlaylist = []; // Keep the original order
  List<Surah> _playbackPlaylist = []; // This list will be shuffled if needed
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

  // --- Add StorageService instance ---
  final StorageService _storageService = StorageService();

  // --- Getters ---
  Surah? get currentSurah => _currentSurah;
  ProcessingState get processingState => _processingState;
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _currentPosition;
  Duration get bufferedPosition => _bufferedPosition;
  Duration get totalDuration => _totalDuration;
  bool get isShuffleModeEnabled => _isShuffleModeEnabled;
  RepeatMode get repeatMode => _repeatMode;

  bool get hasNext {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return false;
      if (_repeatMode == RepeatMode.all || _repeatMode == RepeatMode.one) return true;
      return _currentIndexInPlayback! < _playbackPlaylist.length - 1;
  }

  bool get hasPrevious {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return false;
      if (_repeatMode == RepeatMode.all) return true;
      if (_repeatMode == RepeatMode.one) return true; // Allows restarting current track
      return _currentIndexInPlayback! > 0;
  }

  AudioPlayerService() {
    _init();
  }

  // --- Playlist Management ---
  Future<void> loadPlaylist(List<Surah> playlist, {int? initialIndex}) async {
    _originalPlaylist = List.from(playlist);
    _playbackPlaylist = List.from(playlist);
    _currentIndexInPlayback = null;
    _currentSurah = null;

    if (_isShuffleModeEnabled) {
       _shufflePlaylist(keepCurrent: false);
    }

    await _audioPlayer.stop();
    _processingState = ProcessingState.idle;
    notifyListeners(); // Update UI to show nothing is loaded initially

    int targetIndex = initialIndex ?? 0;

     if (_isShuffleModeEnabled && initialIndex != null) {
         final originalSurah = _originalPlaylist[initialIndex];
         targetIndex = _playbackPlaylist.indexWhere((s) => s.number == originalSurah.number);
         if (targetIndex == -1) targetIndex = 0;
     } else if (initialIndex == null && _isShuffleModeEnabled) {
         targetIndex = 0;
     }

    if (targetIndex >= 0 && targetIndex < _playbackPlaylist.length) {
      await _loadAndPlayIndex(targetIndex);
    }
  }

  void _shufflePlaylist({required bool keepCurrent}) {
      if (_originalPlaylist.isEmpty) return;

      Surah? surahToKeep;
      if (keepCurrent && _currentIndexInPlayback != null) {
         surahToKeep = _playbackPlaylist[_currentIndexInPlayback!];
      }

      _playbackPlaylist = List.from(_originalPlaylist);
      _playbackPlaylist.shuffle(_random);

      if (surahToKeep != null) {
         _playbackPlaylist.removeWhere((s) => s.number == surahToKeep!.number);
         _playbackPlaylist.insert(0, surahToKeep);
         _currentIndexInPlayback = 0;
      } else {
          _currentIndexInPlayback = null;
      }

      print("Playlist shuffled. Current index: $_currentIndexInPlayback");
      // Don't notify here, let loadPlaylist or toggleShuffleMode handle notifications
  }


  Future<void> _loadAndPlayIndex(int index) async {
      if (index < 0 || index >= _playbackPlaylist.length) {
          print("Index out of bounds: $index");
          return;
      }

      try { await _audioPlayer.stop(); } catch(e) { print("Error stopping player: $e"); }

      _currentIndexInPlayback = index;
      _currentSurah = _playbackPlaylist[index];
      _currentPosition = Duration.zero;
      _bufferedPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _processingState = ProcessingState.loading;
      notifyListeners(); // Notify loading state

      try {
          print("Loading Surah [${_currentIndexInPlayback}]: ${_currentSurah!.audioUrl}");
          final source = AudioSource.uri(Uri.parse(_currentSurah!.audioUrl));
          await _audioPlayer.setAudioSource(source, initialPosition: Duration.zero, preload: true);
          print("Surah loaded successfully: ${_currentSurah!.name}");

          if (_currentSurah != null) {
             await _storageService.addRecentSurah(_currentSurah!.number);
          }

          await play();

      } catch (e) {
          print("Error loading audio source at index $index: $e");
          _currentSurah = null;
          _currentIndexInPlayback = null;
          _processingState = ProcessingState.idle;
          notifyListeners(); // Notify error state
      }
  }

  // --- Playback Controls ---
  Future<void> play() async {
     final session = await AudioSession.instance;
     if (await session.setActive(true)) {
         if (_currentSurah != null && (_processingState != ProcessingState.idle && _processingState != ProcessingState.completed) ) {
             try { await _audioPlayer.play(); } catch (e) { print("Error playing audio: $e"); }
         } else if (_processingState == ProcessingState.completed) {
             // If completed, seek to 0 and play
              await seek(Duration.zero);
              try { await _audioPlayer.play(); } catch (e) { print("Error playing audio after completed: $e"); }
         }
     } else { print("Failed to activate audio session"); }
  }

  Future<void> pause() async {
     try { await _audioPlayer.pause(); } catch (e) { print("Error pausing audio: $e"); }
  }

  Future<void> seek(Duration position) async {
      final targetPosition = position.isNegative ? Duration.zero : (position > _totalDuration ? _totalDuration : position);
      try {
        await _audioPlayer.seek(targetPosition);
        // Update state immediately for responsiveness, player stream might lag slightly
        _currentPosition = targetPosition;
        notifyListeners();
      } catch (e) { print("Error seeking audio: $e"); }
  }

  Future<void> playNext() async {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return;
      if (_repeatMode == RepeatMode.one) { seek(Duration.zero); play(); return; }

      int nextIndex = _currentIndexInPlayback! + 1;
      if (nextIndex >= _playbackPlaylist.length) {
          if (_repeatMode == RepeatMode.all) { nextIndex = 0; }
          else {
              print("End of playlist reached.");
              await _audioPlayer.stop();
              _processingState = ProcessingState.completed;
              seek(Duration.zero); // Seek to 0 after completion
              pause(); // Ensure paused state
              notifyListeners();
              return;
          }
      }
      await _loadAndPlayIndex(nextIndex);
  }

  Future<void> playPrevious() async {
      if (_playbackPlaylist.isEmpty || _currentIndexInPlayback == null) return;
      if (_repeatMode == RepeatMode.one) { seek(Duration.zero); play(); return; }

      int previousIndex = _currentIndexInPlayback! - 1;
      if (previousIndex < 0) {
         if (_repeatMode == RepeatMode.all) { previousIndex = _playbackPlaylist.length - 1; }
         else {
             print("Start of playlist reached.");
             await _audioPlayer.stop();
             _processingState = ProcessingState.idle; // Or completed? Idle seems better here
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

      Surah? current = _currentSurah; // Preserve current surah before reshuffling/restoring

      if (_isShuffleModeEnabled) {
          _shufflePlaylist(keepCurrent: true); // Shuffle, keeping current track
      } else {
          _playbackPlaylist = List.from(_originalPlaylist); // Restore original order
          if (current != null) {
              // Find the new index of the current surah in the original list
              _currentIndexInPlayback = _playbackPlaylist.indexWhere((s) => s.number == current.number);
              if (_currentIndexInPlayback == -1) _currentIndexInPlayback = null;
          } else {
              _currentIndexInPlayback = null;
          }
      }
      notifyListeners(); // Notify UI of shuffle state change and potentially new next/prev availability
  }

  Future<void> cycleRepeatMode() async {
      if (_repeatMode == RepeatMode.off) { _repeatMode = RepeatMode.all; }
      else if (_repeatMode == RepeatMode.all) { _repeatMode = RepeatMode.one; }
      else { _repeatMode = RepeatMode.off; }
      print("Repeat mode: $_repeatMode");

       _audioPlayer.setLoopMode(_repeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off);

      notifyListeners(); // Notify UI of repeat state change
  }


  // --- Initialization and Listeners ---
  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

     session.interruptionEventStream.listen((event) {
        if (event.begin) { if (isPlaying) { pause(); } }
        else { /* Handle interruption end if needed */ }
     });
     session.becomingNoisyEventStream.listen((_) { if (isPlaying) { pause(); } });


    _audioPlayer.playerStateStream.listen((playerState) {
      final oldProcessingState = _processingState;
      _processingState = playerState.processingState;

      if (_processingState == ProcessingState.completed && oldProcessingState != ProcessingState.completed) {
          // Handle completion only once when transitioning to completed state
         if (_repeatMode != RepeatMode.one) {
            // Play next will handle RepeatMode.all or stopping for RepeatMode.off
             playNext();
         } else {
            // Rely on player loop mode for RepeatMode.one, but seek/play as fallback
             seek(Duration.zero);
             play();
         }
      }
      // Use kDebugMode for more verbose state logging if needed
      // if (kDebugMode) { print("Player State: Playing=${playerState.playing}, Processing=${playerState.processingState}"); }
      notifyListeners(); // Notify for any state change

    });

    _audioPlayer.positionStream.listen((position) {
        final oldPos = _currentPosition;
        _currentPosition = position;
        if (_currentPosition != oldPos) { notifyListeners(); } // Notify on any change
    });

    _audioPlayer.bufferedPositionStream.listen((buffered) {
        final oldBuffered = _bufferedPosition;
        _bufferedPosition = buffered;
         if (_bufferedPosition != oldBuffered) { notifyListeners(); } // Notify on any change
    });

    _audioPlayer.durationStream.listen((duration) {
       final oldDuration = _totalDuration;
       _totalDuration = duration ?? Duration.zero;
       if(oldDuration != _totalDuration) { notifyListeners(); }
    });

    _audioPlayer.playbackEventStream.listen((event) { /* Handle specific events if needed */ },
        onError: (Object e, StackTrace stackTrace) {
          print('A stream error occurred: $e');
          _processingState = ProcessingState.idle;
          _currentSurah = null;
          _currentIndexInPlayback = null;
          notifyListeners();
        });
  }

  @override
  void dispose() {
     AudioSession.instance.then((session) => session.setActive(false));
    _audioPlayer.dispose();
    super.dispose();
  }
} // End of AudioPlayerService class