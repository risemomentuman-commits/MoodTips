import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../utils/badge_checker.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _userEmail;
  String? _photoUrl;

  final ImagePicker _picker = ImagePicker();

  // ✅ Chemin FIXE (évite de remplir ton bucket avec 100 avatars)
  String? _avatarStoragePath() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    return 'avatars/$userId/avatar.jpg';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      _userEmail = user?.email;

      // Charger l'URL de la photo si elle existe
      final metadata = user?.userMetadata;
      if (metadata != null && metadata['avatar_url'] != null) {
        _photoUrl = metadata['avatar_url'] as String?;
      }

      final profile = await SupabaseService.getProfile();

      if (profile != null) {
        setState(() {
          _profile = profile;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Photo de profil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ Caméra uniquement sur mobile (sur Web c'est aléatoire)
            if (!kIsWeb)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: AppColors.secondary),
              ),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),

            if (_photoUrl != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete, color: AppColors.error),
                ),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePhoto();
                },
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not found');

      final storagePath = _avatarStoragePath();
      if (storagePath == null) throw Exception('Storage path not available');

      // ✅ Cross-platform: bytes (pas de File)
      final Uint8List bytes = await image.readAsBytes();

      // ✅ Upload stable sur Web/iOS/Android
      await Supabase.instance.client.storage
          .from('profiles')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true, // ✅ remplace le fichier existant
            ),
          );

      // URL publique
      final publicUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(storagePath);

      // Mettre à jour les metadata (avatar_url)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      setState(() {
        _photoUrl = publicUrl;
        _isUploadingPhoto = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Photo mise à jour !'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      setState(() => _isUploadingPhoto = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur upload: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _isUploadingPhoto = true);

    try {
      final storagePath = _avatarStoragePath();

      // 1) Nettoyer metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );

      // 2) (Optionnel mais propre) supprimer le fichier Storage
      if (storagePath != null) {
        try {
          await Supabase.instance.client.storage
              .from('profiles')
              .remove([storagePath]);
        } catch (_) {
          // On ne bloque pas l'utilisateur si remove échoue
        }
      }

      setState(() {
        _photoUrl = null;
        _isUploadingPhoto = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Photo supprimée'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isUploadingPhoto = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
                  );
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le mot de passe doit faire au moins 6 caractères')),
                  );
                  return;
                }

                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: newPasswordController.text),
                  );

                  if (!context.mounted) return;

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Mot de passe modifié !'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
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
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Mon profil',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: _showPhotoOptions,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: _isUploadingPhoto
                                        ? Center(
                                            child: CircularProgressIndicator(color: AppColors.primary),
                                          )
                                        : _photoUrl != null
                                            ? ClipOval(
                                                child: Image.network(
                                                  _photoUrl!,
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        gradient: AppColors.primaryGradient,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Container(
                                                decoration: BoxDecoration(
                                                  gradient: AppColors.primaryGradient,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.person, size: 60, color: Colors.white),
                                              ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _showPhotoOptions,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Email
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.email_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMedium,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _userEmail ?? 'Non disponible',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Statistiques
                            if (_profile != null) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.secondary.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.bar_chart, color: AppColors.secondary),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Mes statistiques',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCard(
                                            icon: Icons.check_circle_outline,
                                            value: '${_profile!.totalTipsCompleted}',
                                            label: 'Tips complétés',
                                            color: AppColors.success,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _StatCard(
                                            icon: Icons.local_fire_department,
                                            value: '${_profile!.currentStreak}',
                                            label: 'Jours de suite',
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            ListTile(
                              leading: Icon(Icons.emoji_events, color: AppColors.primary),
                              title: const Text('Mes Badges'),
                              subtitle: const Text('Consulte tes succès'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => Navigator.pushNamed(context, '/badges'),
                            ),

                            // Section Thèmes (bientôt disponible)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.secondary.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.palette_outlined,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Thèmes personnalisés',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bientôt disponible ! 🎨',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Bientôt',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warning,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Bouton Modifier mot de passe
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _showChangePasswordDialog,
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Modifier le mot de passe'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
