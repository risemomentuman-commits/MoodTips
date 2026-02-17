import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class OnboardingSlidesPage extends StatefulWidget {
  @override
  _OnboardingSlidesPageState createState() => _OnboardingSlidesPageState();
}

class _OnboardingSlidesPageState extends State<OnboardingSlidesPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _slides = [
    {'type': 'welcome'},
    {'type': 'irm'},
    {'type': 'intelligent'},
    {'type': 'exercises'},
    {'type': 'start'},
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _fadeController.reset();
      _pageController.nextPage(
        duration: Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      _fadeController.forward();
      HapticFeedback.lightImpact();
    } else {
      _handleComplete();
    }
  }

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.onboardingObjectifs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.04),
                    Colors.white,
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.favorite, color: Colors.white, size: 18),
                          ),
                          SizedBox(width: 8),
                          Text('MoodTips',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              )),
                        ],
                      ),
                      // Passer
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              _slides.length - 1,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text('Passer',
                              style: TextStyle(
                                color: AppColors.textMedium,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _fadeController.reset();
                      _fadeController.forward();
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildSlide(index),
                      );
                    },
                  ),
                ),

                // Indicateurs
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == index ? 28 : 7,
                        height: 7,
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
                              height: 22, width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == _slides.length - 1
                                      ? 'Commencer mon bilan 🌿'
                                      : 'Suivant',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                if (_currentPage < _slides.length - 1) ...[
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(int index) {
   switch (index) {
      case 0: return _buildWelcomeSlide();
      case 1: return _buildIRMSlide();
      case 2: return _buildIntelligentSlide();
      case 3: return _buildExercisesSlide();
      case 4: return _buildStartSlide();
      default: return SizedBox();
    }
  }

  // ── SLIDE 1 : WELCOME ──
  Widget _buildWelcomeSlide() {
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            SizedBox(height: 12),

            // Accroche émotionnelle
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary.withOpacity(0.08), AppColors.secondary.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Text('🌿', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 20),
                  // Questions émotionnelles
                  ...[
                    ('😴', 'Tu te sens souvent épuisé(e)\nsans vraiment savoir pourquoi ?'),
                    ('😰', 'Le stress s\'accumule et tu\nn\'arrives pas à décrocher ?'),
                    ('💭', 'Tu voudrais mieux comprendre\nton état émotionnel ?'),
                  ].map((item) => Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Text(item.$1, style: TextStyle(fontSize: 22)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(item.$2,
                            style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  )),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '✨ MoodTips a été créé pour toi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),
            Text('Bienvenue sur\nMoodTips 🌿',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.2),
              textAlign: TextAlign.center),
            SizedBox(height: 12),
            Text('Ton compagnon de bien-être mental. Comprends tes émotions, préviens l\'épuisement, retrouve l\'équilibre.',
              style: TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.6),
              textAlign: TextAlign.center),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('2 min', 'par jour'),
                _buildStatDivider(),
                _buildStat('100%', 'privé'),
                _buildStatDivider(),
                _buildStat('14j', 'gratuit'),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  // ── SLIDE 3 : IRM ──
  Widget _buildIRMSlide() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: 16),
          // Mock IRM Widget
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🧠 Score IRM', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Color(0xFF4CAF50).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text('🔵 Équilibré', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('78', style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                    Text('/100', style: TextStyle(fontSize: 18, color: Colors.white38, height: 1.8)),
                    Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('↑ +5 pts', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('vs hier', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.78,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    _buildMockFactor('😴', 'Sommeil', '7h'),
                    SizedBox(width: 8),
                    _buildMockFactor('🚶', 'Activité', '6k pas'),
                    SizedBox(width: 8),
                    _buildMockFactor('📅', 'Agenda', 'Léger'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 28),
          Text('Ton Indice de\nRégulation Mentale',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.2),
            textAlign: TextAlign.center),
          SizedBox(height: 14),
          Text('Ton score IRM analyse chaque jour ton sommeil, ton activité et ta charge mentale pour te donner une vision claire de ton équilibre.',
            style: TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.6),
            textAlign: TextAlign.center),
          SizedBox(height: 16),
          _buildFeatureChip('🚨 Alertes avant l\'épuisement pour agir à temps'),
        ],
      ),
    );
  }

  // ── SLIDE 4 : MODE INTELLIGENT ──
  Widget _buildIntelligentSlide() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: Offset(0, 6))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.psychology, color: AppColors.primary, size: 16),
                    ),
                    SizedBox(width: 8),
                    Text('Mode Intelligent actif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Spacer(),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  ],
                ),
                SizedBox(height: 12),
                _buildMockConnection('❤️', 'Apple Health / Google Fit', 'Sommeil · Activité · Énergie', true),
                SizedBox(height: 8),
                _buildMockConnection('📅', 'Calendrier', 'Charge agenda · Événements', true),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('🧠', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Expanded(child: Text('Détecté : Tu sembles fatigué ce soir. Pause recommandée.',
                        style: TextStyle(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text('L\'IA qui te\ncomprend vraiment',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.2),
            textAlign: TextAlign.center),
          SizedBox(height: 12),
          Text('Le Mode Intelligent analyse tes données de santé et ton agenda pour détecter ton état émotionnel automatiquement.',
            style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
            textAlign: TextAlign.center),
          SizedBox(height: 12),
          _buildFeatureChip('🔒 Données traitées localement · Jamais partagées'),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── SLIDE 5 : EXERCICES ──
  Widget _buildExercisesSlide() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                Text('🌬️ Respiration 4-7-8', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Pour réduire le stress · 3 min', style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(height: 16),
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMockStep('1', 'Inspire', '4 sec'),
                    _buildMockStep('2', 'Retiens', '7 sec'),
                    _buildMockStep('3', 'Expire', '8 sec'),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.record_voice_over, color: Colors.white70, size: 13),
                    SizedBox(width: 6),
                    Text('Voix guidée · Marie', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Text('Des exercices guidés\npour chaque état',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.2),
            textAlign: TextAlign.center),
          SizedBox(height: 12),
          Text('Respiration, méditation, mouvement. Des exercices adaptés à ton score IRM du moment, guidés par une voix naturelle.',
            style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
            textAlign: TextAlign.center),
          SizedBox(height: 12),
          _buildFeatureChip('🎖️ Badges et récompenses pour rester motivé'),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── SLIDE 6 : START ──
  Widget _buildStartSlide() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: 20),
          // Illustration finale
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 30, offset: Offset(0, 12))],
            ),
            child: Center(child: Text('🌿', style: TextStyle(fontSize: 60))),
          ),
          SizedBox(height: 28),
          Text('Prêt(e) à prendre\nsoin de toi ? 💙',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.2),
            textAlign: TextAlign.center),
          SizedBox(height: 16),
          Text('Rejoins des milliers d\'utilisateurs qui ont choisi MoodTips pour mieux se comprendre et prévenir l\'épuisement.',
            style: TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.6),
            textAlign: TextAlign.center),
          SizedBox(height: 24),
          // Points clés
          ...[
            ['🔒', 'Données privées et sécurisées (RGPD)'],
            ['⚡', 'Résultats dès le premier jour'],
          ].map((item) => Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(item[0], style: TextStyle(fontSize: 18))),
                ),
                SizedBox(width: 12),
                Text(item[1], style: TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── HELPERS ──
  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 28, color: AppColors.primary.withOpacity(0.15));
  }

  Widget _buildMockEmotion(String label, String emoji, bool selected) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: TextStyle(fontSize: 14)),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textMedium, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildMockFactor(String emoji, String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(height: 2),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildMockConnection(String emoji, String name, String detail, bool connected) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: connected ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(emoji, style: TextStyle(fontSize: 22)),
        SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          Text(detail, style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
        ])),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('Connecté', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildMockStep(String num, String label, String duration) {
    return Column(children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: Center(child: Text(num, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
      SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      Text(duration, style: TextStyle(color: Colors.white60, fontSize: 10)),
    ]);
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }
}