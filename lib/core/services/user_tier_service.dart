import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_tier.dart';

class UserTierService {
  static final UserTierService _instance = UserTierService._internal();
  factory UserTierService() => _instance;
  UserTierService._internal();
  
  final StreamController<UserTier> _tierController = StreamController<UserTier>.broadcast();
  Stream<UserTier> get tierStream => _tierController.stream;
  
  UserTier _currentTier = UserTier.anonymous;
  UserTier get currentTier => _currentTier;
  
  Future<void> initialize() async {
    // Check if user is already authenticated
    final isAuthenticated = await _checkAuthenticationStatus();
    if (isAuthenticated) {
      _currentTier = UserTier.standard; // Default to standard for authenticated users
    } else {
      _currentTier = UserTier.anonymous;
    }
    
    _tierController.add(_currentTier);
    debugPrint('Initialized with tier: ${_currentTier.displayName}');
  }
  
  Future<bool> _checkAuthenticationStatus() async {
    // Check if user has any stored authentication data
    // This would typically check Firebase Auth or local storage
    return false; // For now, assume anonymous
  }
  
  Future<void> upgradeToStandard() async {
    if (_currentTier == UserTier.anonymous) {
      _currentTier = UserTier.standard;
      _tierController.add(_currentTier);
      debugPrint('Upgraded to Standard tier');
    }
  }
  
  Future<void> upgradeToPremium() async {
    if (_currentTier == UserTier.standard) {
      _currentTier = UserTier.premium;
      _tierController.add(_currentTier);
      debugPrint('Upgraded to Premium tier');
    }
  }
  
  Future<void> downgradeToAnonymous() async {
    _currentTier = UserTier.anonymous;
    _tierController.add(_currentTier);
    debugPrint('Downgraded to Anonymous tier');
  }
  
  bool canAccessFeature(String feature) {
    switch (feature) {
      case 'messaging':
        return _currentTier.canMessage;
      case 'saveConnections':
        return _currentTier.canSaveConnections;
      case 'locationMode':
        return _currentTier.canUseLocationMode;
      case 'virtualMode':
        return _currentTier.canUseVirtualMode;
      case 'linkedInIntegration':
        return _currentTier.canUseLinkedInIntegration;
      default:
        return false;
    }
  }
  
  String getFeatureUpgradeMessage(String feature) {
    switch (feature) {
      case 'locationMode':
        return 'Sign up to discover professionals in your area';
      case 'virtualMode':
        return 'Upgrade to Premium to be discoverable 24/7';
      case 'messaging':
        return 'Sign up to message connections and build your network';
      case 'saveConnections':
        return 'Sign up to save your professional network';
      case 'linkedInIntegration':
        return 'Sign up to import your LinkedIn connections';
      default:
        return 'This feature requires an upgrade';
    }
  }
  
  Future<void> dispose() async {
    await _tierController.close();
  }
}
