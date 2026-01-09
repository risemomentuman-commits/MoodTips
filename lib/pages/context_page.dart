import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/supabase_service.dart';

class ContextPage extends StatefulWidget {
  final int emotionId;
  final int moodLogId;

  const ContextPage({
    Key? key,
    required this.emotionId,
    required this.moodLogId,
  }) : super(key: key);

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> with TickerProviderStateMixin {
  String? _selectedLocation;
  String? _selectedCompany;
  String? _selectedTimeOfDay;
  String? _selectedActivity;
  bool _isSaving = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final Map<String, Map<String, dynamic>> _locations = {
    'home': {'label': 'Maison', 'icon': '🏠'},
    'work': {'label': 'Travail', 'icon': '💼'},
    'transport': {'label': 'Transport', 'icon': '🚗'},
    'outdoor': {'label': 'Extérieur', 'icon': '🏃'},
    'public': {'label': 'Lieu public', 'icon': '🏬'},
    'school': {'label': 'École', 'icon': '🏫'},
    'medical': {'label': 'Médical', 'icon': '🏥'},
    'unknown': {'label': 'Je ne sais pas', 'icon': '🤷'},
  };

  final Map<String, Map<String, dynamic>> _companies = {
    'alone': {'label': 'Seul(e)', 'icon': '🧘'},
    'family': {'label': 'Famille', 'icon': '👨‍👩‍👧'},
    'children': {'label': 'Enfants', 'icon': '👶'},
    'friends': {'label': 'Ami(e)s', 'icon': '👫'},
    'colleagues': {'label': 'Collègues', 'icon': '💼'},
    'partner': {'label': 'Partenaire', 'icon': '💑'},
    'strangers': {'label': 'Inconnus', 'icon': '👥'},
    'unknown': {'label': 'Je ne sais pas', 'icon': '🤷'},
  };

  final Map<String, Map<String, dynamic>> _timesOfDay = {
    'morning': {'label': 'Matin', 'icon': '🌅', 'time': '6h-12h'},
    'afternoon': {'label': 'Après-midi', 'icon': '☀️', 'time': '12h-18h'},
    'evening': {'label': 'Soirée', 'icon': '🌆', 'time': '18h-23h'},
    'night': {'label': 'Nuit', 'icon': '🌙', 'time': '23h-6h'},
  };

  final Map<String, Map<String, dynamic>> _activities = {
    'rest': {'label': 'Repos', 'icon': '💤'},
    'work': {'label': 'Travail', 'icon': '💻'},
    'sport': {'label': 'Sport', 'icon': '🏃'},
    'meal': {'label': 'Repas', 'icon': '🍽️'},
    'leisure': {'label': 'Loisirs', 'icon': '🎮'},
    'social': {'label': 'Discussion', 'icon': '💬'},
    'commute': {'label': 'Déplacement', 'icon': '🚗'},
    'sleep': {'label': 'Coucher', 'icon': '🛏️'},
    'unknown': {'label': 'Je ne sais pas', 'icon': '🤷'},
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    // Auto-sélectionner le moment de la journée basé sur l'heure actuelle
    _autoSelectTimeOfDay();
  }

  void _autoSelectTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      _selectedTimeOfDay = 'morning';
    } else if (hour >= 12 && hour < 18) {
      _selectedTimeOfDay = 'afternoon';
    } else if (hour >= 18 && hour < 23) {
      _selectedTimeOfDay = 'evening';
    } else {
      _selectedTimeOfDay = 'night';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    return _selectedLocation != null &&
        _selectedCompany != null &&
        _selectedTimeOfDay != null &&
        _selectedActivity != null;
  }

  Future<void> _saveAndContinue() async {
    if (!_canContinue) return;

    setState(() => _isSaving = true);

    try {
      // Sauvegarder le contexte
      await SupabaseService.saveMoodContext(
        moodLogId: widget.moodLogId,
        location: _selectedLocation!,
        company: _selectedCompany!,
        timeOfDay: _selectedTimeOfDay!,
        activity: _selectedActivity!,
      );

      if (!mounted) return;

      // Naviguer vers les tips
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.tipsResult,
        arguments: widget.emotionId,
      );
    } catch (e) {
      print('Erreur sauvegarde contexte: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

              // Contenu scrollable
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24),

                        // Lieu
                        _buildSection(
                          title: 'Où es-tu ?',
                          icon: Icons.place_outlined,
                          options: _locations,
                          selectedValue: _selectedLocation,
                          onSelect: (value) => setState(() => _selectedLocation = value),
                        ),

                        SizedBox(height: 32),

                        // Compagnie
                        _buildSection(
                          title: 'Avec qui ?',
                          icon: Icons.people_outline,
                          options: _companies,
                          selectedValue: _selectedCompany,
                          onSelect: (value) => setState(() => _selectedCompany = value),
                        ),

                        SizedBox(height: 32),

                        // Moment
                        _buildSection(
                          title: 'Quel moment ?',
                          icon: Icons.access_time,
                          options: _timesOfDay,
                          selectedValue: _selectedTimeOfDay,
                          onSelect: (value) => setState(() => _selectedTimeOfDay = value),
                        ),

                        SizedBox(height: 32),

                        // Activité
                        _buildSection(
                          title: 'Que fais-tu ?',
                          icon: Icons.directions_run,
                          options: _activities,
                          selectedValue: _selectedActivity,
                          onSelect: (value) => setState(() => _selectedActivity = value),
                        ),

                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Optionnel',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Contexte',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aide-nous à mieux comprendre ce qui influence ton humeur',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Map<String, Map<String, dynamic>> options,
    required String? selectedValue,
    required Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.entries.map((entry) {
            final isSelected = selectedValue == entry.key;
            return _buildOptionChip(
              emoji: entry.value['icon'],
              label: entry.value['label'],
              subtitle: entry.value['time'],
              isSelected: isSelected,
              onTap: () => onSelect(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String emoji,
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white.withOpacity(0.8) : AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _canContinue && !_isSaving ? _saveAndContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _canContinue ? Colors.white : AppColors.textLight,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: _canContinue ? Colors.white : AppColors.textLight,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
