import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class OnboardingObjectifsPage extends StatefulWidget {
  @override
  _OnboardingObjectifsPageState createState() => _OnboardingObjectifsPageState();
}

class _OnboardingObjectifsPageState extends State<OnboardingObjectifsPage> {
  bool _fromSettings = false;  
  final Map<String, bool> _selectedGoals = {
    'reduce_stress': false,
    'better_sleep': false,
    'more_energy': false,
    'manage_emotions': false,
    'improve_focus': false,
    'self_care': false,
  };

  final Map<String, String> _goalLabels = {
    'reduce_stress': 'Réduire mon stress',
    'better_sleep': 'Mieux dormir',
    'more_energy': 'Augmenter mon énergie',
    'manage_emotions': 'Gérer mes émotions',
    'improve_focus': 'Améliorer mon focus',
    'self_care': 'Prendre soin de moi',
  };

  final Map<String, IconData> _goalIcons = {
    'reduce_stress': Icons.spa_outlined,
    'better_sleep': Icons.bedtime_outlined,
    'more_energy': Icons.bolt_outlined,
    'manage_emotions': Icons.psychology_outlined,
    'improve_focus': Icons.center_focus_strong_outlined,
    'self_care': Icons.self_improvement_outlined,
  };

  bool _isLoading = false;
  bool _isLoadingData = true;

  int get _selectedCount => _selectedGoals.values.where((v) => v).length;

  @override
  void initState() {
    super.initState();
    _loadExistingGoals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  
    // ✅ AJOUT : Détecter si vient des paramètres
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _fromSettings = args?['fromSettings'] == true;
  }

  Future<void> _loadExistingGoals() async {
    setState(() => _isLoadingData = true);
    
    try {
      final profile = await SupabaseService.getProfile();
      
      if (profile != null && profile.mainGoals != null) {
        setState(() {
          // Réinitialiser toutes les cases
          _selectedGoals.updateAll((key, value) => false);
          
          // Cocher les objectifs existants
          for (var goal in profile.mainGoals!) {
            if (_selectedGoals.containsKey(goal)) {
              _selectedGoals[goal] = true;
            }
          }
        });
      }
    } catch (e) {
      print('Erreur chargement objectifs: $e');
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handleSave() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sélectionne au moins un objectif 💜'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedList = _selectedGoals.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await SupabaseService.updateProfile({
        'main_goals': selectedList,
      });

      if (!mounted) return;

      // Afficher confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Objectifs enregistrés ! ✨'),
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
    Navigator.pushNamed(context, AppRoutes.onboardingPreferences);
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

  Widget _buildGoalCard(String key, String label, IconData icon, int index) {
    final isSelected = _selectedGoals[key] ?? false;

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
              onTap: () => setState(() => _selectedGoals[key] = !isSelected),
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
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.primary.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: isSelected ? 20 : 10,
                      offset: Offset(0, isSelected ? 8 : 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.white, size: 24),
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
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.05),
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
                      CircularProgressIndicator(color: AppColors.primary),
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
                    // Header avec bouton retour
                    // Header
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Mes objectifs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
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
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.flag_outlined, size: 32, color: Colors.white),
                            ),

                            SizedBox(height: 24),

                            // Titre
                            Text(
                              'Quels sont tes\nobjectifs ?',
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
                              'Sélectionne tout ce qui te correspond',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textMedium,
                              ),
                            ),

                            SizedBox(height: 8),

                            // Compteur
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey(_selectedCount),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_selectedCount objectif${_selectedCount > 1 ? 's' : ''} ✨',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
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
                                itemCount: _goalLabels.length,
                                separatorBuilder: (context, index) => SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final entry = _goalLabels.entries.elementAt(index);
                                  return _buildGoalCard(
                                    entry.key,
                                    entry.value,
                                    _goalIcons[entry.key]!,
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
                                  backgroundColor: AppColors.primary,
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
