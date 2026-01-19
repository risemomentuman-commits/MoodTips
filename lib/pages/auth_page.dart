import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class AuthPage extends StatefulWidget {
  final String? message;
  final bool initialIsLogin;
  final String? prefillEmail;
  
  const AuthPage({
    Key? key,
    this.message,
    this.initialIsLogin = true,
    this.prefillEmail,
  }) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    
    // Pré-remplir l'email si fourni
    if (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty) {
      _emailController.text = widget.prefillEmail!;
    }
    
    // Afficher le message si présent
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: 'https://risemomentuman-commits.github.io/MoodTips/#/welcome',
      );

      if (!mounted) return;

      if (response.user != null) {
        // Afficher dialog de succès
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read,
                  size: 60,
                  color: AppColors.primary,
                ),
                SizedBox(height: 20),
                Text(
                  'Email de confirmation envoyé !',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Vérifie ta boîte mail ${_emailController.text}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Clique sur le lien de confirmation puis reviens ici.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isLogin = true;
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Compris !'),
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
      } else if (e.message.contains('already registered')) {
        errorMessage = 'Cet email est déjà utilisé. Connecte-toi plutôt !';
      } else if (e.message.contains('invalid email')) {
        errorMessage = 'Email invalide. Vérifie ton adresse.';
      } else if (e.message.contains('weak password')) {
        errorMessage = 'Mot de passe trop faible. Utilise au moins 6 caractères.';
      } else {
        errorMessage = 'Erreur : ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur inattendue. Réessaie dans quelques instants.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

      // Vérifier si onboarding déjà complété
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final profile = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', userId)
          .maybeSingle();
        
        final onboardingCompleted = profile?['onboarding_completed'] ?? false;
        
        if (!mounted) return;
        
        if (onboardingCompleted) {
          Navigator.pushReplacementNamed(context, AppRoutes.welcome);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        }
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
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

  Future<void> _handleLogin() async {
    if (_isLogin) {
      await _signIn();
    } else {
      // en mode signup, on exige confirmation mdp
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Les mots de passe ne correspondent pas.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      await _signUp();
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
                  // Logo / Illustration
                  Container(
                    height: 120,
                    margin: EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.self_improvement,
                      size: 64,
                      color: AppColors.primary,
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
                    _isLogin ? 'Connectez-vous pour continuer' : 'Créez votre compte pour commencer',
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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
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

                  // Bouton Se connecter
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.createAccount,
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
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
  Future<void> _showResendEmailDialog() async {
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Renvoyer l\'email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entre ton email pour recevoir un nouveau lien de confirmation :',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Envoyer'),
          ),
        ],
      ),
    );
    
    if (result == true && emailController.text.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: emailController.text.trim(),
        );
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de confirmation renvoyé !'),
            backgroundColor: AppColors.primary,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

                  
  
