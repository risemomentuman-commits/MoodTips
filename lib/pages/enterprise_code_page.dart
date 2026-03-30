import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class EnterpriseCodePage extends StatefulWidget {
  const EnterpriseCodePage({Key? key}) : super(key: key);

  @override
  State<EnterpriseCodePage> createState() => _EnterpriseCodePageState();
}

class _EnterpriseCodePageState extends State<EnterpriseCodePage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _foundOrg;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() { _isLoading = true; _error = null; _foundOrg = null; });

    try {
      final response = await Supabase.instance.client
          .from('organizations')
          .select('id, name, plan, seat_limit, invite_code')
          .eq('invite_code', code)
          .eq('active', true)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _error = 'Code invalide ou expiré. Vérifie auprès de ton entreprise.';
          _isLoading = false;
        });
        return;
      }

      // Vérifier les sièges disponibles
      final membersCount = await Supabase.instance.client
          .from('organization_members')
          .select('id')
          .eq('organization_id', response['id']);

      if ((membersCount as List).length >= response['seat_limit']) {
        setState(() {
          _error = 'Cette organisation a atteint sa limite de membres. Contacte ton responsable RH.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _foundOrg = response;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion. Réessaie.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                '🏢 Code entreprise',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Entre le code fourni par ton responsable RH ou ton entreprise.',
                style: TextStyle(fontSize: 15, color: AppColors.textMedium),
              ),
              SizedBox(height: 40),

              // Champ code
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: AppColors.primary,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 6,
                    color: AppColors.textMedium.withOpacity(0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                ),
                onChanged: (v) {
                  if (_error != null) setState(() => _error = null);
                  if (_foundOrg != null) setState(() => _foundOrg = null);
                },
              ),

              SizedBox(height: 16),

              // Erreur
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFDEDEC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFC0392B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(fontSize: 13, color: Color(0xFFC0392B)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Org trouvée
              if (_foundOrg != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text('🏢', style: TextStyle(fontSize: 22))),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundOrg!['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '✓ Organisation vérifiée · Accès Premium inclus',
                              style: TextStyle(fontSize: 12, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.createAccount,
                      arguments: {
                        'accountType': 'enterprise',
                        'organizationId': _foundOrg!['id'],
                        'organizationName': _foundOrg!['name'],
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Créer mon compte',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],

              if (_foundOrg == null)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _validateCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24, width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Valider le code',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

              SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Je n\'ai pas de code entreprise',
                    style: TextStyle(color: AppColors.textMedium, fontSize: 13),
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
