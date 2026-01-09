import 'package:flutter/material.dart';

class AppColors {
  // ========== PALETTE "NATURE APAISANTE" ==========
  // Tons naturels universels inspirés de la nature
  // Vert sauge + Terre + Rose argile
  // Parfait pour homme ET femme
  
  // ========== BASE NATURELLE (90%) ==========
  
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
  
  // ========== COULEUR PRIMAIRE NATURELLE ==========
  
  /// Vert sauge - Nature, croissance, paix
  /// ✅ Universel (ni masculin ni féminin)
  /// ✅ Apaisant (associé à la nature)
  /// ✅ Doux (pas agressif)
  static const Color primary = Color(0xFF88A77E);
  
  /// Vert sauge foncé - Hover, états actifs
  static const Color primaryDark = Color(0xFF6B8C63);
  
  /// Vert sauge clair - Backgrounds légers
  static const Color primaryLight = Color(0xFFA8BFA0);
  
  /// Vert sauge ultra clair - Hover subtil
  static const Color primaryUltraLight = Color(0xFFD4E2CF);
  
  // ========== ACCENTS NATURELS (10%) ==========
  
  /// Terre de sienne - Chaleur, humanité, réconfort
  static const Color warmAccent = Color(0xFFC19A6B);
  
  /// Terre foncée
  static const Color warmAccentDark = Color(0xFFA77D52);
  
  /// Terre claire
  static const Color warmAccentLight = Color(0xFFD9BF9E);
  
  /// Rose argile - Douceur féminine subtile
  static const Color softAccent = Color(0xFFD4ACA0);
  
  /// Rose argile foncé
  static const Color softAccentDark = Color(0xFFBF9488);
  
  /// Rose argile clair
  static const Color softAccentLight = Color(0xFFE8CFC7);
  
  /// Bleu-vert eau - Fraîcheur masculine subtile
  static const Color freshAccent = Color(0xFF9DB5AC);
  
  /// Bleu-vert foncé
  static const Color freshAccentDark = Color(0xFF7D9B8F);
  
  /// Bleu-vert clair
  static const Color freshAccentLight = Color(0xFFC2D5CD);
  
  // ========== COULEURS SYSTÈME ==========
  
  /// Succès - Vert nature
  static const Color success = Color(0xFF7FA677);
  
  /// Erreur - Terracotta doux (pas rouge agressif)
  static const Color error = Color(0xFFD17A6C);
  
  /// Warning - Ocre naturel
  static const Color warning = Color(0xFFD9A96B);
  
  /// Info - Bleu-vert calme
  static const Color info = Color(0xFF88B5A8);
  
  // ========== CATÉGORIES (Palette naturelle) ==========
  
  static const Map<String, Color> categories = {
    'respiration': Color(0xFF9DB5AC),  // Bleu-vert eau (souffle)
    'mouvement': Color(0xFF88A77E),    // Vert sauge (nature)
    'mental': Color(0xFFA88F9E),       // Mauve taupe (profondeur)
    'musique': Color(0xFFD4ACA0),      // Rose argile (créativité)
  };
  
  // ========== ÉMOTIONS (Tons naturels doux) ==========
  
  static const Map<String, Color> emotions = {
    // Positives - Tons chauds naturels
    'joyeux': Color(0xFFE8C594),       // Miel doré
    'heureux': Color(0xFFD9BF9E),      // Sable chaud
    'calme': Color(0xFFA8BFA0),        // Vert pâle
    'confiant': Color(0xFF88A77E),     // Vert sauge
    'énergique': Color(0xFFD9A96B),    // Ocre vif
    
    // Négatives - Tons froids apaisés
    'triste': Color(0xFFA8B5C2),       // Gris-bleu pâle
    'anxieux': Color(0xFFB8ADBA),      // Mauve grisé
    'anxiété': Color(0xFFB8ADBA),      // Alias
    'en_colere': Color(0xFFD4ACA0),    // Rose argile
    'colère': Color(0xFFD4ACA0),       // Alias
    'stress': Color(0xFF9DB5AC),       // Bleu-vert
    'fatigue': Color(0xFFC7C2BA),      // Taupe pâle
    'débordé': Color(0xFFD4D0C8),      // Beige gris
    'frustré': Color(0xFFCFAD8F),      // Caramel pâle
  };
  
  // ========== DÉGRADÉS NATURELS ==========
  
  /// Dégradé principal - Vert sauge
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF88A77E),  // Vert sauge
      Color(0xFF6B8C63),  // Vert sauge foncé
    ],
  );
  
  /// Dégradé de fond - Beige doux
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF7F5F2),  // Beige nuage
      Color(0xFFFFFEFC),  // Blanc crème
    ],
  );
  
  /// Dégradé chaleur - Terre de sienne
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC19A6B),  // Terre
      Color(0xFFA77D52),  // Terre foncée
    ],
  );
  
  /// Dégradé douceur - Rose argile
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4ACA0),  // Rose argile
      Color(0xFFBF9488),  // Rose argile foncé
    ],
  );
  
  /// Dégradé fraîcheur - Bleu-vert
  static const LinearGradient freshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9DB5AC),  // Bleu-vert
      Color(0xFF7D9B8F),  // Bleu-vert foncé
    ],
  );
  
  /// Dégradé nature complète
  static const LinearGradient natureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF88A77E),  // Vert sauge
      Color(0xFF9DB5AC),  // Bleu-vert
      Color(0xFFC19A6B),  // Terre
    ],
  );
  
  // ========== ALIASES DE COMPATIBILITÉ ==========
  
  static const Color background = backgroundPrimary;
  static const Color backgroundGrey = surfaceLight;
  static const Color textGrey = textMedium;
  
  /// Secondary = Terre de sienne (chaleur)
  static const Color secondary = warmAccent;
  
  /// Accent = Bleu-vert (fraîcheur)
  static const Color accent = freshAccent;
  
  // Anciens accents → Équivalents naturels
  static const Color lavender = Color(0xFFA88F9E);  // Mauve taupe
  static const Color lavenderDark = Color(0xFF8F7687);
  static const Color rosePowder = softAccent;
  static const Color rosePowderDark = softAccentDark;
  
  // ========== OMBRES NATURELLES SUBTILES ==========
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: textDark.withOpacity(0.06),  // Ombre verte subtile
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
      color: primary.withOpacity(0.20),  // Ombre vert sauge
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
  
  // ========== GUIDE D'UTILISATION ==========
  
  /*
  🌿 PALETTE "NATURE APAISANTE"
  
  ================================
  PHILOSOPHIE
  ================================
  
  "Inspiré par la nature, apaisant pour tous"
  
  - Tons terreux = Ancrage, stabilité
  - Vert sauge = Croissance, paix, nature
  - Rose argile = Douceur humaine
  - Bleu-vert = Fraîcheur, clarté
  - Beige = Neutralité absolue
  
  ✅ Universel : Homme ET Femme
  ✅ Apaisant : Nature + Tons doux
  ✅ Non agressif : Pas de couleurs vives
  ✅ Contrasté : Éléments bien délimités
  
  ================================
  RÉPARTITION DES COULEURS
  ================================
  
  🌿 VERT SAUGE (#88A77E) - 60%
  → Primary : Boutons, éléments d'action
  → Associé à : Nature, croissance, paix
  → Genre : Neutre absolu
  
  🏜️ TERRE DE SIENNE (#C19A6B) - 15%
  → Accent chaleur : Célébrations, streak
  → Associé à : Chaleur humaine, réconfort
  → Genre : Neutre, légèrement masculin
  
  🌸 ROSE ARGILE (#D4ACA0) - 15%
  → Accent douceur : Feedback positif
  → Associé à : Douceur, humanité
  → Genre : Neutre, légèrement féminin
  
  💧 BLEU-VERT (#9DB5AC) - 10%
  → Accent fraîcheur : Respiration, calme
  → Associé à : Eau, clarté, fraîcheur
  → Genre : Neutre, légèrement masculin
  
  ================================
  EXEMPLES D'UTILISATION
  ================================
  
  ✅ Bouton principal (vert sauge) :
  ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    child: Text('Valider'),
  )
  
  ✅ Badge streak (terre) :
  Container(
    color: AppColors.warmAccent,
    child: Row(
      children: [
        Icon(Icons.local_fire_department, color: Colors.white),
        Text('3 jours', style: TextStyle(color: Colors.white)),
      ],
    ),
  )
  
  ✅ Feedback positif (rose argile) :
  Container(
    decoration: BoxDecoration(
      gradient: AppColors.softGradient,
    ),
    child: Text('Bravo ! 🎉', style: TextStyle(color: Colors.white)),
  )
  
  ✅ Card respiration (bleu-vert) :
  Container(
    decoration: BoxDecoration(
      color: AppColors.freshAccent.withOpacity(0.1),
      border: Border.all(color: AppColors.freshAccent),
    ),
    child: Text('Respiration'),
  )
  
  ✅ Fond de page (beige nuage) :
  Scaffold(
    backgroundColor: AppColors.backgroundPrimary,
  )
  
  ================================
  RÉSULTAT VISUEL
  ================================
  
  🌿 Naturel : Évoque forêt, terre, végétation
  🕊️ Apaisant : Tons doux, pas agressifs
  ⚖️ Universel : Homme ET Femme se sentent bien
  🎨 Contrasté : Cards blanches sur fond beige
  💚 Vivant : Assez de couleur sans être trop
  
  Parfait pour une app de wellness mixte !
  
  ================================
  ASSOCIATIONS ÉMOTIONNELLES
  ================================
  
  Vert sauge → Nature, paix, croissance
  Terre de sienne → Chaleur, ancrage, sécurité
  Rose argile → Douceur, humanité, bienveillance
  Bleu-vert → Clarté, fraîcheur, respiration
  Beige → Neutralité, calme, repos
  
  🎯 Aucune couleur n'évoque la tristesse ou l'agressivité
  */
}
