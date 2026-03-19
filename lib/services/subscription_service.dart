import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  static const String _iosApiKey = 'appl_UXtDvyjTuWMjXbkEOUnjZoxcgkF';
  static const String _androidApiKey = '';
  static const String _entitlementId = 'premium';
  static const int _trialDays = 14;

  static bool _isInitialized = false;
  static bool _isPremium = false;
  static int _trialDaysRemaining = 0;
  static bool _trialExpired = false;

  static bool get isPremium => _isPremium;
  static int get trialDaysRemaining => _trialDaysRemaining;
  static bool get trialExpired => _trialExpired;

  /// L'utilisateur a acces aux features premium
  static bool get hasAccess => _isPremium || !_trialExpired;
  static final ValueNotifier<bool> accessNotifier = ValueNotifier(false);

  /// Initialiser RevenueCat
  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return;

    try {
      String apiKey;
      if (Platform.isIOS) {
        apiKey = _iosApiKey;
      } else if (Platform.isAndroid) {
        if (_androidApiKey.isEmpty) {
          print('⚠️ RevenueCat Android API key not configured');
          _isInitialized = true;
          await _checkTrialStatus();
          return;
        }
        apiKey = _androidApiKey;
      } else {
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isInitialized = true;
      print('✅ RevenueCat initialise');

      await checkPremiumStatus();
      await _checkTrialStatus();

      Purchases.addCustomerInfoUpdateListener((info) {
        _updatePremiumStatus(info);
      });
    } catch (e) {
      print('⚠️ RevenueCat init failed: $e');
      _isInitialized = true;
      await _checkTrialStatus();
    }
  }

  /// Verifier le statut du trial (base sur created_at du profil)
  static Future<void> _checkTrialStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _trialExpired = true;
        _trialDaysRemaining = 0;
        return;
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        _trialExpired = true;
        _trialDaysRemaining = 0;
        return;
      }

      final createdAt = DateTime.parse(response['created_at']);
      final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      _trialDaysRemaining = _trialDays - daysSinceCreation;

      if (_trialDaysRemaining < 0) _trialDaysRemaining = 0;
      _trialExpired = daysSinceCreation >= _trialDays;

      print('📅 Trial: ${_trialDaysRemaining}j restants, expire: $_trialExpired');
    } catch (e) {
      print('⚠️ Erreur verification trial: $e');
      _trialExpired = false;
      _trialDaysRemaining = 14;
    }
    accessNotifier.value = hasAccess;
  }

  /// Rafraichir le statut trial (appeler periodiquement)
  static Future<void> refreshTrialStatus() async {
    await _checkTrialStatus();
    print('📅 Trial refresh: ${_trialDaysRemaining}j restants, premium: $_isPremium, access: $hasAccess');
  }

  /// Login RevenueCat
  static Future<void> login(String userId) async {
    if (!_isInitialized) return;
    try {
      if (_iosApiKey.isNotEmpty || _androidApiKey.isNotEmpty) {
        await Purchases.logIn(userId);
      }
      await checkPremiumStatus();
      await _checkTrialStatus();
      print('✅ RevenueCat user: $userId');
    } catch (e) {
      print('⚠️ RevenueCat login error: $e');
    }
  }

  /// Logout RevenueCat
  static Future<void> logout() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
      _isPremium = false;
      _trialExpired = true;
      _trialDaysRemaining = 0;
    } catch (e) {
      print('⚠️ RevenueCat logout error: $e');
    }
  }

  /// Verifier le statut premium RevenueCat
  static Future<bool> checkPremiumStatus() async {
    if (!_isInitialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      _updatePremiumStatus(info);
      return _isPremium;
    } catch (e) {
      print('⚠️ Erreur verification premium: $e');
      return false;
    }
  }

  static void _updatePremiumStatus(CustomerInfo info) {
    _isPremium = info.entitlements.active.containsKey(_entitlementId);
    accessNotifier.value = hasAccess;
    print('💎 Premium: $_isPremium');
  }

  /// Recuperer les offres
  static Future<Offerings?> getOfferings() async {
    if (!_isInitialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('⚠️ Erreur offres: $e');
      return null;
    }
  }

  /// Acheter un package
  static Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;
    try {
      final result = await Purchases.purchasePackage(package);
      _updatePremiumStatus(result.customerInfo);
      return _isPremium;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        print('🚫 Achat annule');
      } else {
        print('❌ Erreur achat: $e');
      }
      return false;
    }
  }

  /// Restaurer les achats
  static Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      _updatePremiumStatus(info);
      return _isPremium;
    } catch (e) {
      print('⚠️ Erreur restauration: $e');
      return false;
    }
  }
}