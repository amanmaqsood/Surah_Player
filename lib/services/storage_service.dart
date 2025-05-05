// lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _recentsKey = 'recent_surahs';
  static const String _favoritesKey = 'favorite_surahs'; // New key for favorites
  static const int _maxRecents = 20;

  // --- Recents ---
  Future<void> addRecentSurah(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recents = prefs.getStringList(_recentsKey) ?? [];

    // Convert number to string for storage
    String surahNumStr = surahNumber.toString();

    // Remove if already exists to avoid duplicates and move to top
    recents.remove(surahNumStr);

    // Add to the beginning of the list
    recents.insert(0, surahNumStr);

    // Trim the list if it exceeds the maximum size
    if (recents.length > _maxRecents) {
      recents = recents.sublist(0, _maxRecents);
    }

    await prefs.setStringList(_recentsKey, recents);
    print("Added Surah $surahNumber to recents. Current recents: $recents");
  }

  Future<List<int>> getRecentSurahNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> recentsStr = prefs.getStringList(_recentsKey) ?? [];
    // Convert back to integers, handle potential parsing errors
    return recentsStr
        .map((str) => int.tryParse(str))
        .where((num) => num != null) // Filter out any nulls from failed parsing
        .cast<int>() // Cast the result back to List<int>
        .toList();
  }

  // --- Favorites ---

  Future<void> _saveFavorites(Set<String> favoritesSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favoritesSet.toList());
  }

  Future<Set<String>> _getFavoritesSet() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? []).toSet();
  }

  // Adds a surah number to favorites
  Future<void> addFavorite(int surahNumber) async {
    final Set<String> favorites = await _getFavoritesSet();
    favorites.add(surahNumber.toString());
    await _saveFavorites(favorites);
    print("Added Surah $surahNumber to favorites. Current favorites: $favorites");
  }

  // Removes a surah number from favorites
  Future<void> removeFavorite(int surahNumber) async {
    final Set<String> favorites = await _getFavoritesSet();
    favorites.remove(surahNumber.toString());
    await _saveFavorites(favorites);
     print("Removed Surah $surahNumber from favorites. Current favorites: $favorites");
  }

  // Toggles favorite status for a surah number
  Future<bool> toggleFavorite(int surahNumber) async {
     final Set<String> favorites = await _getFavoritesSet();
     final String surahNumStr = surahNumber.toString();
     bool isCurrentlyFavorite;
     if (favorites.contains(surahNumStr)) {
        favorites.remove(surahNumStr);
        isCurrentlyFavorite = false;
     } else {
        favorites.add(surahNumStr);
        isCurrentlyFavorite = true;
     }
     await _saveFavorites(favorites);
     print("Toggled favorite for Surah $surahNumber. Is now favorite: $isCurrentlyFavorite");
     return isCurrentlyFavorite; // Return the new status
  }


  // Checks if a surah number is favorite
  Future<bool> isFavorite(int surahNumber) async {
    final Set<String> favorites = await _getFavoritesSet();
    return favorites.contains(surahNumber.toString());
  }

  // Gets all favorite surah numbers
  Future<List<int>> getFavoriteSurahNumbers() async {
    final Set<String> favoritesStr = await _getFavoritesSet();
    return favoritesStr
        .map((str) => int.tryParse(str))
        .where((num) => num != null)
        .cast<int>()
        .toList();
        // Optionally sort the numbers: .toList()..sort();
  }
}

