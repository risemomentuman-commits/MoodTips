import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../main.dart'; // ✅ Pour accéder à MyApp.reload()

class ThemeSelectionPage extends StatefulWidget {
  const ThemeSelectionPage({Key? key}) : super(key: key);

  @override
  State<ThemeSelectionPage> createState() => _ThemeSelectionPageState();
}

class _ThemeSelectionPageState extends State<ThemeSelectionPage>
    with SingleTickerProviderStateMixin {
  String _selectedTheme = AppColors.currentThemeId;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choisis le thème qui te ressemble',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Liste des thèmes
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    itemCount: AppColors.availableThemes.length,
                    itemBuilder: (context, index) {
                      final theme = AppColors.availableThemes[index];
                      final isSelected = _selectedTheme == theme.key;

                      return _buildThemeCard(
                        themeId: theme.key,
                        name: theme.value.name,
                        emoji: theme.value.emoji,
                        colors: [
                          theme.value.primary,
                          theme.value.secondary,
                        ],
                        isSelected: isSelected,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Text(
            'Thèmes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppColors.currentThemeEmoji,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(width: 4),
                Text(
                  'Actuel',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String themeId,
    required String name,
    required String emoji,
    required List<Color> colors,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        setState(() => _selectedTheme = themeId);
        await AppColors.setTheme(themeId);
        
        // ✅ Recharger toute l'app
        MyApp.reload();
        
        await Future.delayed(Duration(milliseconds: 200));
        
        if (mounted) {
          // ✅ Pop jusqu'à revenir à MoodCheckPage (home)
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors[0] : AppColors.surfaceLight,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colors[0].withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Emoji
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Nom du thème
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Check si sélectionné
                  if (isSelected)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
