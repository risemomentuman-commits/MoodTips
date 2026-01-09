import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class OnboardingPreferencesPage extends StatefulWidget {
  @override
  _OnboardingPreferencesPageState createState() => _OnboardingPreferencesPageState();
}

class _OnboardingPreferencesPageState extends State<OnboardingPreferencesPage> {
  bool _fromSettings = false;  
  final Map<String, bool> _selectedCategories = {
    'respiration': false,
    'mouvement': false,
    'mental': false,
   'musique': false,
  };

  final Map<String, String> _categoryLabels = {
    'respiration': 'Respiration',
    'mouvement': 'Mouvement',
    'mental': 'Mental',
    'musique': 'Musique',
  };

  final Map<String, String> _categoryEmojis = {
    'respiration': '🫁',
    'mouvement': '🏃',
    'mental': '🧠',
    'musique': '🎵',
  };

  final Map<String, String> _categoryDescriptions = {
    'respiration': 'Cohérence cardiaque et relaxation',
    'mouvement': 'Micro-exercices et étirements',
    'mental': 'Méditation et mindfulness',
    'musique': 'Playlists apaisantes',
  };

  bool _isLoading = false;
  bool _isLoadingData = true;

  int get _selectedCount => _selectedCategories.values.where((v) => v).length;

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // ✅ AJOUT : Détecter si vient des paramètres
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  _fromSettings = args?['fromSettings'] == true;
}

  Future<void> _loadExistingPreferences() async {
    setState(() => _isLoadingData = true);
    
    try {
      final profile = await SupabaseService.getProfile();
      
      if (profile != null) {
        setState(() {
          // Réinitialiser toutes les cases
          _selectedCategories.updateAll((key, value) => false);
          
          // ✅ CORRECTION : Lire depuis preferences au lieu de preferredCategories
          if (profile.preferences != null && 
              profile.preferences!['categories'] != null) {
            final categories = profile.preferences!['categories'] as List<dynamic>;
            
            for (var category in categories) {
              final categoryStr = category.toString();
              if (_selectedCategories.containsKey(categoryStr)) {
                _selectedCategories[categoryStr] = true;
              }
            }
          }
        });
      }
    } catch (e) {
      print('❌ Erreur chargement préférences: $e');
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handleSave() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choisis au moins une catégorie 💜'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedList = _selectedCategories.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      // ✅ CORRECTION : Format JSON correct
      await SupabaseService.updateProfile({
        'preferences': {'categories': selectedList},
      });

      if (!mounted) return;

      // Afficher confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Préférences enregistrées ! ✨'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: Duration(seconds: 2),
        ),
      );

      // Retour à la page précédente
      await Future.delayed(Duration(milliseconds: 500));
if (mounted) {
  if (_fromSettings) {
    // Vient des paramètres → Retour simple
    Navigator.pop(context);
  } else {
    // Onboarding normal → Continuer
    Navigator.pushNamed(context, AppRoutes.onboardingConsent);
  }
}
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCategoryCard(String key, String emoji, String label, String description, int index) {
    final isSelected = _selectedCategories[key] ?? false;
    final color = AppColors.categories[key] ?? AppColors.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategories[key] = !isSelected),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.05),
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: isSelected ? 20 : 10,
                      offset: Offset(0, isSelected ? 8 : 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: Duration(milliseconds: 200),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.2)
                              : color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary.withOpacity(0.1),
              AppColors.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoadingData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.secondary),
                      SizedBox(height: 16),
                      Text(
                        'Chargement...',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Mes préférences',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icône
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.secondary,
                                    AppColors.primary,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.favorite_rounded, size: 32, color: Colors.white),
                            ),

                            SizedBox(height: 24),

                            // Titre
                            Text(
                              'Quelles pratiques\nt\'attirent ?',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                height: 1.2,
                              ),
                            ),

                            SizedBox(height: 12),

                            // Sous-titre
                            Text(
                              'Choisis tes catégories favorites',
                              style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                            ),

                            SizedBox(height: 8),

                            // Compteur
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey(_selectedCount),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_selectedCount catégorie${_selectedCount > 1 ? 's' : ''} ✨',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 32),

                            // Liste
                            Expanded(
                              child: ListView.separated(
                                physics: BouncingScrollPhysics(),
                                itemCount: _categoryLabels.length,
                                separatorBuilder: (context, index) => SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final entry = _categoryLabels.entries.elementAt(index);
                                  return _buildCategoryCard(
                                    entry.key,
                                    _categoryEmojis[entry.key]!,
                                    entry.value,
                                    _categoryDescriptions[entry.key]!,
                                    index,
                                  );
                                },
                              ),
                            ),

                            SizedBox(height: 24),

                            // Bouton Enregistrer
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check, size: 24),
                                          SizedBox(width: 8),
                                          Text(
                                            'Enregistrer',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
