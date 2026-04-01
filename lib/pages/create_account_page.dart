import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({Key? key}) : super(key: key);

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Les mots de passe ne correspondent pas'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // ✅ Capturer les args AVANT tout appel async
    final args           = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final accountType    = args?['accountType']    as String?;
    final organizationId = args?['organizationId'] as String?;
    final invitedId      = args?['invitedId']      as String?;

    print('📦 Args B2B: accountType=$accountType, orgId=$organizationId, invitedId=$invitedId');

    try {
      if (accountType == 'enterprise' && organizationId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_org_id', organizationId);
        await prefs.setString('invited_id', invitedId ?? '');
        print('💾 OrgId sauvegardé localement: $organizationId');
      }
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: 'https://risemomentuman-commits.github.io/MoodTips/#/auth',
        data: {
          'pending_org_id': organizationId ?? '',
          'account_type':   accountType   ?? '',
          'invited_id':     invitedId     ?? '',
        },
      );

      if (!mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await SubscriptionService.login(user.id);

        // ✅ Marquer l'email comme utilisé dans la whitelist
        if (invitedId != null) {
          await Supabase.instance.client
              .from('organization_invited_emails')
              .update({
                'used':    true,
                'used_at': DateTime.now().toIso8601String(),
              })
              .eq('id', invitedId);
          print('✅ Email marqué comme utilisé');
        }

        // ✅ Stocker l'org en attente pour activation au premier login
        if (accountType == 'enterprise' && organizationId != null) {
          try {
            await Supabase.instance.client
              .from('profiles')
              .update({'pending_org_id': organizationId})
              .eq('id', user.id);
            print('✅ Org en attente enregistrée: $organizationId');
            
          } catch (e) {
            print('⚠️ Erreur enregistrement org: $e');
          }
        }
      }

      if (response.user != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_read, size: 60, color: AppColors.primary),
                SizedBox(height: 20),
                Text(
                  'Email de confirmation envoyé !',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Vérifie ta boîte mail ${_emailController.text}',
                  style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Clique sur le lien de confirmation puis reviens ici pour te connecter.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.auth,
                      arguments: {'message': 'Email envoyé ! Vérifie ta boîte mail puis connecte-toi.'},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Compris !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      String errorMessage;
      if (e.message.contains('rate_limit') || e.message.contains('email_send_rate_limit')) {
        errorMessage = 'Trop de tentatives. Attends 1 minute et réessaie.';
      } else if (e.message.contains('already registered') || e.message.contains('User already registered')) {
        errorMessage = 'Cet email est déjà utilisé. Connecte-toi plutôt !';
      } else if (e.message.contains('invalid email')) {
        errorMessage = 'Email invalide. Vérifie ton adresse.';
      } else if (e.message.contains('weak password')) {
        errorMessage = 'Mot de passe trop faible. Utilise au moins 6 caractères.';
      } else {
        errorMessage = 'Erreur : ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error, duration: Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur inattendue. Réessaie dans quelques instants.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Créer votre compte', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                SizedBox(height: 8),
                Text('Rejoignez MoodTips et commencez votre voyage vers le bien-être', style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.backgroundGrey,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Veuillez entrer votre email';
                    if (!value.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.backgroundGrey,
                    helperText: 'Minimum 6 caractères',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Veuillez entrer un mot de passe';
                    if (value.length < 6) return 'Le mot de passe doit contenir au moins 6 caractères';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignUp(),
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.backgroundGrey,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Veuillez confirmer votre mot de passe';
                    return null;
                  },
                ),
                SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text('Créer mon compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Vous avez déjà un compte ? ', style: TextStyle(color: AppColors.textGrey)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Se connecter', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
