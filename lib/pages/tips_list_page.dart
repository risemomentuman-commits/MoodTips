import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/tip.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class TipsListPage extends StatefulWidget {
  @override
  _TipsListPageState createState() => _TipsListPageState();
}

class _TipsListPageState extends State<TipsListPage> {
  List<Tip> _tips = [];
  List<Tip> _filteredTips = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final Map<String, String> _categories = {
    'all': 'Tous',
    'respiration': 'Respiration',
    'mouvement': 'Mouvement',
    'mental': 'Mental',
    'musique': 'Musique',
  };

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    setState(() => _isLoading = true);

    try {
      final tips = await SupabaseService.getTips();
      setState(() {
        _tips = tips;
        _filterTips();
      });
    } catch (e) {
      print('Erreur chargement tips: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterTips() {
    setState(() {
      if (_selectedCategory == 'all') {
        _filteredTips = _tips;
      } else {
        _filteredTips = _tips.where((tip) => tip.category == _selectedCategory).toList();
      }
    });
  }

  Color _getCategoryColor(String category) {
    return AppColors.categories[category] ?? AppColors.primary;
  }

  String _getCategoryEmoji(String category) {
    const emojis = {
      'respiration': '🌬️',
      'mouvement': '🏃',
      'mental': '🧠',
      'musique': '🎵',
    };
    return emojis[category] ?? '✨';
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
              // Header avec bouton retour
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Bouton retour
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 8),
                    // Titre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tous les tips',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${_filteredTips.length} exercice${_filteredTips.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filtres catégories
              Container(
                height: 50,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final entry = _categories.entries.elementAt(index);
                    final isSelected = _selectedCategory == entry.key;

                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = entry.key;
                          _filterTips();
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textMedium,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 16),

              // Liste des tips
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _filteredTips.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: AppColors.textLight,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Aucun tip dans cette catégorie',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredTips.length,
                            itemBuilder: (context, index) {
                              final tip = _filteredTips[index];
                              return _buildTipCard(tip);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(Tip tip) {
    final color = _getCategoryColor(tip.category);
    final emoji = _getCategoryEmoji(tip.category);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.tipsDetail,
              arguments: tip.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Emoji
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: TextStyle(fontSize: 28)),
                  ),
                ),

                SizedBox(width: 16),

                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _categories[tip.category] ?? tip.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          if (tip.durationMinutes != null) ...[
                            SizedBox(width: 8),
                            Icon(Icons.access_time, size: 14, color: AppColors.textLight),
                            SizedBox(width: 4),
                            Text(
                              tip.durationMinutes != null ? '${tip.durationMinutes} min' : 'Variable',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Flèche
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
