// lib/models/surah.dart
class Surah {
  final int number;
  final String name; // Transliterated name
  final String englishName;
  final int numberOfAyahs;
  final String audioUrl;
  final String reciter; // Added reciter field

  Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.numberOfAyahs,
    required this.audioUrl,
    this.reciter = "Yasser Al-Dosari", // Default reciter for this source
  });

  // Optional: Factory constructor to create Surah from JSON map
  factory Surah.fromJson(Map<String, dynamic> json, String audioUrlBase, String reciterName) {
     int number = json['number'];
     // Format number for URL (e.g., 1 -> 001, 10 -> 010, 100 -> 100)
     String formattedNumber = number.toString().padLeft(3, '0');
     String audioUrl = '$audioUrlBase/$formattedNumber.mp3';

    return Surah(
      number: number,
      name: json['name'],
      englishName: json['englishName'],
      numberOfAyahs: json['numberOfAyahs'],
      audioUrl: audioUrl,
      reciter: reciterName, // Use the provided reciter name
    );
  }
}