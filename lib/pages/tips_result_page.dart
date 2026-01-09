import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/tip.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class TipsResultPage extends StatefulWidget {
  final int emotionId;

  TipsResultPage({required this.emotionId});

  @override
  _TipsResultPageState createState() => _TipsResultPageState();
}

class _TipsResultPageState extends State<TipsResultPage> {
  Future<List<Tip>>? _tipsFuture;
  bool _showAllTips = false;

  @override
  void initState() {
    super.initState();
    _tipsFuture = SupabaseService.getRecommendedTips(widget.emotionId);
  }

  Color _getCategoryColor(String category) {
    return AppColors.categories[category] ?? AppColors.primary;
  }

  IconData _getCategoryIconData(String category) {
    const icons = {
      'respiration': Icons.air_outlined,
      'mouvement': Icons.directions_run_outlined,
      'mental': Icons.psychology_outlined,
      'nutrition': Icons.restaurant_outlined,
      'musique': Icons.music_note_outlined,
    };
    return icons[category] ?? Icons.spa_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Vos tips du jour',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: FutureBuilder<List<Tip>>(
            future: _tipsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Préparation de vos tips...',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(fontSize: 18, color: AppColors.textDark),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _tipsFuture = SupabaseService.getRecommendedTips(
                              widget.emotionId,
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }

              final tips = snapshot.data ?? [];

              if (tips.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_neutral,
                          size: 64,
                          color: AppColors.textGrey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun tip disponible pour le moment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Revenez plus tard ou essayez une autre émotion',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Séparer les tips : Top 3 + Reste
              final topTips = tips.take(3).toList();
              final moreTips = tips.length > 3 ? tips.skip(3).toList() : <Tip>[];

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Nos recommandations pour vous',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Commencez par l\'un de ces exercices',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Liste des tips
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // Section "TOP 3"
                        ...topTips.asMap().entries.map((entry) {
                          int index = entry.key;
                          Tip tip = entry.value;
                          return _buildTopTipCard(tip, index + 1);
                        }).toList(),

                        // Bouton "Voir plus" si il y a d'autres tips
                        if (moreTips.isNotEmpty && !_showAllTips) ...[
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllTips = true;
                              });
                            },
                            icon: Icon(Icons.expand_more),
                            label: Text('Voir ${moreTips.length} autre${moreTips.length > 1 ? 's' : ''} tip${moreTips.length > 1 ? 's' : ''}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],

                        // Autres tips (si "Voir plus" cliqué)
                        if (_showAllTips && moreTips.isNotEmpty) ...[
                          SizedBox(height: 24),
                          Text(
                            'Autres suggestions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 12),
                          ...moreTips.map((tip) => _buildTipCard(tip)).toList(),
                        ],

                        SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Bouton retour au mood check
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(
                          context,
                          ModalRoute.withName(AppRoutes.moodCheck),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 56),
                      ),
                      child: Text(
                        'Refaire le check-in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Carte "Top 3" avec badge numéro
  Widget _buildTopTipCard(Tip tip, int rank) {
    final color = _getCategoryColor(tip.category);
    final icon = _getCategoryIconData(tip.category);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.tipsDetail,
          arguments: tip.id,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge numéro
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Badge catégorie
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      SizedBox(width: 6),
                      Text(
                        tip.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Spacer(),

                // Durée
                if (tip.durationMinutes != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${tip.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Titre
            Text(
              tip.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),

            SizedBox(height: 8),

            // Description courte
            Text(
              tip.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),

            SizedBox(height: 16),

            // Bouton "Commencer"
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.buttonShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.tipsDetail,
                      arguments: tip.id,
                    );
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Commencer cet exercice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carte tip normale (pour les tips après le top 3)
  Widget _buildTipCard(Tip tip) {
    final color = _getCategoryColor(tip.category);
    final icon = _getCategoryIconData(tip.category);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.tipsDetail,
          arguments: tip.id,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            // Icône de catégorie
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            SizedBox(width: 16),

            // Infos du tip
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge catégorie
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tip.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),

                  // Titre
                  Text(
                    tip.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),

                  // Durée
                  if (tip.durationMinutes != null)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.textGrey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${tip.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Flèche
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
