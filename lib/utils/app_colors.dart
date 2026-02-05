import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  // ========== SYSTÈME DE THÈMES ==========
  
  static final Map<String, ThemePalette> _themes = {
    'sage': ThemePalette(
      name: 'Vert Sauge',
      emoji: '🌿',
      primary: Color(0xFF88A77E),
      primaryDark: Color(0xFF6B8C63),
      primaryLight: Color(0xFFA8BFA0),
      secondary: Color(0xFFC19A6B),
      accent: Color(0xFF9DB5AC),
    ),
    'lavender': ThemePalette(
      name: 'Lavande & Rose',
      emoji: '💜',
      primary: Color(0xFFB8A4D4),
      primaryDark: Color(0xFF9B7EBD),
      primaryLight: Color(0xFFD4C7E8),
      secondary: Color(0xFFF4C7D8),
      accent: Color(0xFFE8A8C7),
    ),
    'ocean': ThemePalette(
      name: 'Océan Apaisant',
      emoji: '🌊',
      primary: Color(0xFF89B5D9),
      primaryDark: Color(0xFF5B9BD5),
      primaryLight: Color(0xFFB8D4E8),
      secondary: Color(0xFF9FCDC4),
      accent: Color(0xFF7AB8AC),
    ),
    'peach': ThemePalette(
      name: 'Pêche Douce',
      emoji: '🍑',
      primary: Color(0xFFF4B4A4),
      primaryDark: Color(0xFFE89685),
      primaryLight: Color(0xFFFFD6CC),
      secondary: Color(0xFFFFE4D6),
      accent: Color(0xFFFFB8A0),
    ),
    'mint': ThemePalette(
      name: 'Menthe Fraîche',
      emoji: '🌱',
      primary: Color(0xFF9FCDC4),
      primaryDark: Color(0xFF7AB8AC),
      primaryLight: Color(0xFFD4E9E4),
      secondary: Color(0xFFB8E6D5),
      accent: Color(0xFF88D5C0),
    ),
    'sunset': ThemePalette(
      name: 'Coucher de Soleil',
      emoji: '🌅',
      primary: Color(0xFFFF9A8B),
      primaryDark: Color(0xFFFF7B6B),
      primaryLight: Color(0xFFFFBFB3),
      secondary: Color(0xFFFFDAB9),
      accent: Color(0xFFFFB88C),
    ),
  };

  static String _currentThemeId = 'sage';
  static ThemePalette get _currentTheme => _themes[_currentThemeId]!;

  // ========== COULEURS DYNAMIQUES (changent avec le thème) ==========
  
  static Color get primary => _currentTheme.primary;
  static Color get primaryDark => _currentTheme.primaryDark;
  static Color get primaryLight => _currentTheme.primaryLight;
  static Color get primaryUltraLight => _currentTheme.primary.withOpacity(0.2);
  static Color get secondary => _currentTheme.secondary;
  static Color get accent => _currentTheme.accent;

  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryDark],
      );

  static LinearGradient get streakGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [primary, secondary],
      );

  // ========== COULEURS FIXES (ne changent pas) ==========
  
  /// Fond principal - Beige nuage (aurore matinale)
  static const Color backgroundPrimary = Color(0xFFF7F5F2);
  
  /// Cards & surfaces - Blanc crème (lin naturel)
  static const Color backgroundSecondary = Color(0xFFFFFEFC);
  
  /// Texte principal - Vert-gris forêt (mousse des bois)
  static const Color textDark = Color(0xFF2F4538);
  
  /// Texte secondaire - Taupe (pierre naturelle)
  static const Color textMedium = Color(0xFF73786E);
  
  /// Texte tertiaire - Gris sable clair
  static const Color textLight = Color(0xFFA8A99F);
  
  /// Surface alternative - Beige ultra pâle
  static const Color surfaceLight = Color(0xFFF9F7F4);
  
  /// Surface blanche pure - Modales
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  /// Bordures - Beige moyen
  static const Color border = Color(0xFFE8E4DE);
  
  /// Bordures actives - Taupe clair
  static const Color borderActive = Color(0xFFD4D0C8);
  
  // ========== ACCENTS NATURELS FIXES ==========
  
  /// Terre de sienne - Chaleur, humanité, réconfort
  static const Color warmAccent = Color(0xFFC19A6B);
  static const Color warmAccentDark = Color(0xFFA77D52);
  static const Color warmAccentLight = Color(0xFFD9BF9E);
  
  /// Rose argile - Douceur féminine subtile
  static const Color softAccent = Color(0xFFD4ACA0);
  static const Color softAccentDark = Color(0xFFBF9488);
  static const Color softAccentLight = Color(0xFFE8CFC7);
  
  /// Bleu-vert eau - Fraîcheur masculine subtile
  static const Color freshAccent = Color(0xFF9DB5AC);
  static const Color freshAccentDark = Color(0xFF7D9B8F);
  static const Color freshAccentLight = Color(0xFFC2D5CD);
  
  // ========== COULEURS SYSTÈME ==========
  
  static const Color success = Color(0xFF7FA677);
  static const Color error = Color(0xFFD17A6C);
  static const Color warning = Color(0xFFD9A96B);
  static const Color info = Color(0xFF88B5A8);
  
  // ========== CATÉGORIES ==========
  
  static const Map<String, Color> categories = {
    'respiration': Color(0xFF9DB5AC),
    'mouvement': Color(0xFF88A77E),
    'mental': Color(0xFFA88F9E),
    'musique': Color(0xFFD4ACA0),
  };
  
  // ========== ÉMOTIONS ==========
  
  static const Map<String, Color> emotions = {
    'joyeux': Color(0xFFE8C594),
    'heureux': Color(0xFFD9BF9E),
    'calme': Color(0xFFA8BFA0),
    'confiant': Color(0xFF88A77E),
    'énergique': Color(0xFFD9A96B),
    'triste': Color(0xFFA8B5C2),
    'anxieux': Color(0xFFB8ADBA),
    'anxiété': Color(0xFFB8ADBA),
    'en_colere': Color(0xFFD4ACA0),
    'colère': Color(0xFFD4ACA0),
    'stress': Color(0xFF9DB5AC),
    'fatigue': Color(0xFFC7C2BA),
    'débordé': Color(0xFFD4D0C8),
    'frustré': Color(0xFFCFAD8F),
  };
  
  // ========== DÉGRADÉS FIXES ==========
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF7F5F2),
      Color(0xFFFFFEFC),
    ],
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC19A6B),
      Color(0xFFA77D52),
    ],
  );
  
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4ACA0),
      Color(0xFFBF9488),
    ],
  );
  
  static const LinearGradient freshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9DB5AC),
      Color(0xFF7D9B8F),
    ],
  );
  
  static const LinearGradient natureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF88A77E),
      Color(0xFF9DB5AC),
      Color(0xFFC19A6B),
    ],
  );
  
  // ========== ALIASES DE COMPATIBILITÉ ==========
  
  static const Color background = backgroundPrimary;
  static const Color backgroundGrey = surfaceLight;
  static const Color textGrey = textMedium;
  static const Color lavender = Color(0xFFA88F9E);
  static const Color lavenderDark = Color(0xFF8F7687);
  static const Color rosePowder = softAccent;
  static const Color rosePowderDark = softAccentDark;
  
  // ========== OMBRES ==========
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: textDark.withOpacity(0.06),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: textDark.withOpacity(0.04),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withOpacity(0.20),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get lavenderShadow => [
    BoxShadow(
      color: Color(0xFFA88F9E).withOpacity(0.25),
      blurRadius: 15,
      offset: Offset(0, 6),
    ),
  ];
  
  static List<BoxShadow> get roseShadow => [
    BoxShadow(
      color: softAccent.withOpacity(0.25),
      blurRadius: 15,
      offset: Offset(0, 6),
    ),
  ];
  
  // ========== HELPER METHODS ==========
  
  static Color getEmotionColor(String emotionName) {
    return emotions[emotionName.toLowerCase()] ?? textMedium;
  }
  
  static Color getCategoryColor(String category) {
    return categories[category.toLowerCase()] ?? textMedium;
  }
  
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  // ========== GESTION DES THÈMES ==========
  
  static List<MapEntry<String, ThemePalette>> get availableThemes =>
      _themes.entries.toList();

  static String get currentThemeId => _currentThemeId;
  
  static String get currentThemeName => _currentTheme.name;
  
  static String get currentThemeEmoji => _currentTheme.emoji;

  static Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentThemeId = prefs.getString('app_theme') ?? 'sage';
      print('✅ Thème chargé: $_currentThemeId');
    } catch (e) {
      print('❌ Erreur chargement thème: $e');
      _currentThemeId = 'sage';
    }
  }

  static Future<void> setTheme(String themeId) async {
    if (_themes.containsKey(themeId)) {
      _currentThemeId = themeId;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_theme', themeId);
        print('✅ Thème sauvegardé: $themeId');
      } catch (e) {
        print('❌ Erreur sauvegarde thème: $e');
      }
    }
  }
}

// ========== PALETTE DE THÈME ==========

class ThemePalette {
  final String name;
  final String emoji;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondary;
  final Color accent;

  const ThemePalette({
    required this.name,
    required this.emoji,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
  });
}
