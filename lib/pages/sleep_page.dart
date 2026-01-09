import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../utils/app_colors.dart';

class SleepPage extends StatefulWidget {
  @override
  _SleepPageState createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  String? _currentSound;
  int _selectedTimer = 30; // minutes
  Timer? _sleepTimer;
  int _remainingSeconds = 0;
  
  final List<Map<String, dynamic>> _sounds = [
    {
      'id': 'rain',
      'name': 'Pluie douce',
      'emoji': '🌧️',
      'file': 'rain.mp3',
      'color': Color(0xFF6B8CAE),
    },
    {
      'id': 'ocean',
      'name': 'Vagues océan',
      'emoji': '🌊',
      'file': 'ocean.mp3',
      'color': Color(0xFF4A90A4),
    },
    {
      'id': 'forest',
      'name': 'Forêt la nuit',
      'emoji': '🌲',
      'file': 'forest.mp3',
      'color': Color(0xFF5F8A6F),
    },
    {
      'id': 'whitenoise',
      'name': 'Bruit blanc',
      'emoji': '⚪',
      'file': 'whitenoise.mp3',
      'color': Color(0xFF8B8B8B),
    },
    {
      'id': 'piano',
      'name': 'Piano ambiant',
      'emoji': '🎹',
      'file': 'piano.mp3',
      'color': Color(0xFF7E6B8F),
    },
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> _playSound(String soundId) async {
    final sound = _sounds.firstWhere((s) => s['id'] == soundId);
    
    try {
      if (_isPlaying && _currentSound == soundId) {
        // Stop si déjà en train de jouer
        await _audioPlayer.stop();
        _sleepTimer?.cancel();
        setState(() {
          _isPlaying = false;
          _currentSound = null;
          _remainingSeconds = 0;
        });
      } else {
        // Jouer le nouveau son
        await _audioPlayer.stop();
        await _audioPlayer.setSource(AssetSource('audio/${sound['file']}'));
        await _audioPlayer.setVolume(0.7);
        await _audioPlayer.resume();
        
        // Démarrer le timer
        _startSleepTimer();
        
        setState(() {
          _isPlaying = true;
          _currentSound = soundId;
        });
      }
    } catch (e) {
      print('❌ Erreur lecture audio : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : fichier audio introuvable'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startSleepTimer() {
    _sleepTimer?.cancel();
    _remainingSeconds = _selectedTimer * 60;
    
    _sleepTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            
            // Fade out progressif dans les 30 dernières secondes
            if (_remainingSeconds <= 30) {
              final volume = _remainingSeconds / 30 * 0.7;
              _audioPlayer.setVolume(volume);
            }
          } else {
            // Timer terminé
            _audioPlayer.stop();
            _sleepTimer?.cancel();
            _isPlaying = false;
            _currentSound = null;
            _remainingSeconds = 0;
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1F35),
              Color(0xFF2D3E50),
              Color(0xFF34495E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Aide au sommeil',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Timer actif (si en cours)
              if (_isPlaying)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Arrêt automatique dans',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 32),

              // Sélecteur de timer
              if (!_isPlaying) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durée du minuteur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [15, 30, 45, 60].map((minutes) {
                          return _buildTimerChip(minutes);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
              ],

              // Liste des sons
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _sounds.length,
                  itemBuilder: (context, index) {
                    final sound = _sounds[index];
                    final isPlaying = _isPlaying && _currentSound == sound['id'];
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _playSound(sound['id']),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? (sound['color'] as Color).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPlaying
                                    ? sound['color'] as Color
                                    : Colors.white.withOpacity(0.2),
                                width: isPlaying ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Emoji
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: (sound['color'] as Color).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      sound['emoji'],
                                      style: TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                
                                SizedBox(width: 16),
                                
                                // Nom
                                Expanded(
                                  child: Text(
                                    sound['name'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                
                                // Indicateur play/pause
                                Icon(
                                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Info en bas
              Container(
                padding: EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Le son s\'arrêtera automatiquement',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimerChip(int minutes) {
    final isSelected = _selectedTimer == minutes;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTimer = minutes),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Text(
          '${minutes}min',
          style: TextStyle(
            color: isSelected ? Color(0xFF2D3E50) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

  