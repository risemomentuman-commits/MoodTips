import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/consent_service.dart';
import 'forgot_password_page.dart';
import '../services/subscription_service.dart';

class AuthPage extends StatefulWidget {
  final String? message;
  
  const AuthPage({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ConsentService _consentService = ConsentService();

  @override
  void initState() {
    super.initState();
    
    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.message!),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 4),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Login RevenueCat
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await SubscriptionService.login(user.id);
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {

        // Vérifier si activation B2B en attente
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('pending_org_id, is_b2b, onboarding_completed')
            .eq('id', userId)
            .maybeSingle();

        final pendingOrgId   = profile?['pending_org_id'];
        final isAlreadyB2B   = profile?['is_b2b'] ?? false;
        final onboardingCompleted = profile?['onboarding_completed'] ?? false;

        if (pendingOrgId != null && !isAlreadyB2B) {
          await Supabase.instance.client.from('organization_members').upsert({
            'organization_id': pendingOrgId,
            'user_id':         userId,
            'role':            'member',
            'consent_given':   false,
          }, onConflict: 'organization_id,user_id');
          await SubscriptionService.activateB2BPremium(userId);
          await Supabase.instance.client
              .from('profiles')
              .update({'pending_org_id': null})
              .eq('id', userId);
          print('✅ B2B activé au premier login');
        }

        if (!mounted) return;

        if (onboardingCompleted) {
          final hasCgu = await _consentService.hasCguAccepted();
          if (!mounted) return;
          if (hasCgu) {
            Navigator.pushReplacementNamed(context, AppRoutes.moodCheck);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.onboardingConsent);
          }
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        }
      }

    } on AuthException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Email ou mot de passe incorrect.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage = 'Email non confirmé. Vérifie ta boîte mail !';
      } else {
        errorMessage = 'Erreur : ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur inattendue. Réessaie.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo 
                  Container(
                    height: 120,
                    width: 120,
                    margin: EdgeInsets.only(bottom: 32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Titre
                  Text(
                    'Bienvenue sur MoodTips',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),

                  // Sous-titre
                  Text(
                    'Connectez-vous pour continuer',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 48),

                  // Champ Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGrey,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      if (!value.contains('@')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Champ Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGrey,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton Se connecter
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.streakGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.buttonShadow,
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ou',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Bouton Créer un compte
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.streakGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.buttonShadow,
                    ),
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.accountType
                              );
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                        ),
          
                      ),
                      child: Text(
                        'Créer un compte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}