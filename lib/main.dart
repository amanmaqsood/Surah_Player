// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_audio_player/services/audio_player_service.dart';
import 'package:quran_audio_player/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AudioPlayerService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the target colors
    const Color primaryRedPink = Color(0xFFE91E63); // For active elements like play button, progress
    const Color secondaryLightPink = Color(0xFFF06292); // For icons in list/miniplayer
    const Color lightBackground = Color(0xFFFFF9F9); // For home screen background
    const Color darkerPinkBackground = Color(0xFFFADADD); // For Now Playing background
    const Color darkText = Colors.black87;
    const Color greyText = Colors.grey; // Or Colors.black54

    return MaterialApp(
      title: 'Quran Audio Player',
      theme: ThemeData(
        fontFamily: 'Roboto', // Example font, adjust if needed
        useMaterial3: true, // Keep M3 enabled
        scaffoldBackgroundColor: lightBackground, // Default background for Scaffold
        colorScheme: ColorScheme.fromSeed(
          seedColor: secondaryLightPink, // Use a pink seed
          brightness: Brightness.light,
          primary: primaryRedPink,         // Main interactive color
          secondary: secondaryLightPink,    // Accent color for less interactive elements
          background: lightBackground,    // Default background color
          surface: Colors.white,          // Color for Card, Dialog, Search bar background etc.
          onPrimary: Colors.white,        // Color for text/icons on primary color
          onSecondary: Colors.black,      // Color for text/icons on secondary color
          onBackground: darkText,         // Color for text/icons on background color
          onSurface: darkText,          // Color for text/icons on surface color
        ),

        // Specific component themes
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Make AppBar background transparent by default
          elevation: 0,
          iconTheme: IconThemeData(color: darkText), // Icons in AppBar
          titleTextStyle: TextStyle(
              color: darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto' // Ensure consistent font
              ),
        ),

        // Theme for ListTiles if needed
        listTileTheme: const ListTileThemeData(
          iconColor: secondaryLightPink, // Default icon color for ListTiles
          // titleTextStyle: TextStyle(fontWeight: FontWeight.bold, color: darkText), // Handled in widget
          // subtitleTextStyle: TextStyle(color: greyText), // Handled in widget
        ),

        // Theme for Icons (can be overridden)
         iconTheme: IconThemeData(
             color: Colors.grey[700], // Default grey for icons like top nav, more_vert
             size: 24,
         ),

         // Theme for Slider (affects NowPlayingScreen progress bar)
         sliderTheme: SliderThemeData(
            trackHeight: 4.0,
            activeTrackColor: primaryRedPink,
            inactiveTrackColor: primaryRedPink.withOpacity(0.3),
            thumbColor: primaryRedPink,
            overlayColor: primaryRedPink.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0), // Slightly smaller thumb
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
         ),

         // Theme for TextFields (Search Bar)
         inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white, // White background for search bar
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none, // No border
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none,
            ),
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
            prefixIconColor: Colors.grey[600], // Color for search icon
         ),
         // Ensure text themes use the font
         textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto', bodyColor: darkText, displayColor: darkText)
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}