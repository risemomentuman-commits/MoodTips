import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class OnboardingSlidesPage extends StatefulWidget {
  @override
  _OnboardingSlidesPageState createState() => _OnboardingSlidesPageState();
}

class _OnboardingSlidesPageState extends State<OnboardingSlidesPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'title': 'Chaque jour, dis-nous\ncomment tu te sens',
      'description': 'Un simple check-in quotidien pour prendre soin de toi',
      'color': AppColors.emotions['heureux']!
    },
    {
      'icon': Icons.spa_outlined,
      'title': 'Reçois des tips\nadaptés à ton état',
      'description': 'Respiration, mouvement et mindfulness personnalisés',
      'color': AppColors.primary
    },
    {
      'icon': Icons.trending_up_rounded,
      'title': 'Suis ton évolution\nau fil du temps',
      'description': 'Statistiques et insights sur ton bien-être',
      'color': AppColors.success
    },
    {
      'icon': Icons.celebration_outlined,
      'title': 'C\'est parti ! 🎉',
      'description': 'Configure ton expérience en quelques étapes',
      'color': AppColors.secondary
    },
  ];

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);
    
    try {
      // ✅ CORRECTION : Naviguer vers Objectifs au lieu de MoodCheck
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.onboardingObjectifs);
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

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleComplete();
    }
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
              AppColors.primary.withOpacity(0.05),
              AppColors.secondary.withOpacity(0.03),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Bouton Passer
              if (_currentPage < _slides.length - 1)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: () => _pageController.animateToPage(
                        _slides.length - 1,
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: 64),

              // Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icône animée
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        slide['color'].withOpacity(0.2),
                                        slide['color'].withOpacity(0.05),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: slide['color'].withOpacity(0.2),
                                        blurRadius: 30,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    slide['icon'],
                                    size: 70,
                                    color: slide['color'],
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 48),

                          // Titre
                          Text(
                            slide['title'],
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 16),

                          // Description
                          Text(
                            slide['description'],
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMedium,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Indicateurs
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Bouton
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
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
                              Text(
                                _currentPage == _slides.length - 1
                                    ? 'Continuer'
                                    : 'Suivant',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
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
