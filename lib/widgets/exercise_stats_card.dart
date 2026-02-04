// lib/widgets/exercise_stats_card.dart
// Card Dashboard affichant les statistiques des exercices

import 'package:flutter/material.dart';
import '../services/exercise_stats_service.dart';
import '../utils/app_colors.dart';

class ExerciseStatsCard extends StatefulWidget {
  @override
  _ExerciseStatsCardState createState() => _ExerciseStatsCardState();
}

class _ExerciseStatsCardState extends State<ExerciseStatsCard> {
  ExerciseStats? _stats;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    final stats = await ExerciseStatsService.getExerciseStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_stats == null || _stats!.totalCompleted == 0) {
      return SizedBox.shrink(); // Ne rien afficher si pas d'exercices
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.streakGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.insights, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tes exercices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Stats principales
          Row(
            children: [
              Expanded(
                child: _buildMainStat(
                  value: '${_stats!.totalCompleted}',
                  label: 'Complétés',
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMainStat(
                  value: '${_stats!.improvementRate.toInt()}%',
                  label: 'Efficaces',
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Répartition des feedbacks
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildFeedbackRow('😊 Mieux', _stats!.betterCount, _stats!.totalCompleted, Color(0xFF10B981)),
                SizedBox(height: 8),
                _buildFeedbackRow('😐 Pareil', _stats!.sameCount, _stats!.totalCompleted, Color(0xFFD9A96B)),
                SizedBox(height: 8),
                _buildFeedbackRow('😔 Moins bien', _stats!.worseCount, _stats!.totalCompleted, Color(0xFFD17A6C)),
              ],
            ),
          ),
          
          // Top exercices
          if (_stats!.topExercises.isNotEmpty) ...[
            SizedBox(height: 20),
            Text(
              '⭐ Les plus efficaces',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            ..._stats!.topExercises.map((exercise) => _buildTopExercise(exercise)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMainStat({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeedbackRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0;
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          '$count (${percentage.toInt()}%)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTopExercise(TopExercise exercise) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Color(0xFFFBBF24), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${exercise.timesCompleted}x complété',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${exercise.successRate.toInt()}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
