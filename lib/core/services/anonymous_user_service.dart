import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnonymousUserService {
  static final AnonymousUserService _instance = AnonymousUserService._internal();
  factory AnonymousUserService() => _instance;
  AnonymousUserService._internal();
  
  final StreamController<AnonymousUserProfile> _profileController = 
      StreamController<AnonymousUserProfile>.broadcast();
  
  Stream<AnonymousUserProfile> get profileStream => _profileController.stream;
  AnonymousUserProfile? _currentProfile;
  AnonymousUserProfile? get currentProfile => _currentProfile;
  
  static const String _profileKey = 'anonymous_user_profile';
  static const String _sessionIdKey = 'anonymous_session_id';
  
  Future<void> initialize() async {
    await _loadProfile();
    if (_currentProfile == null) {
      await _createAnonymousProfile();
    }
    
    _profileController.add(_currentProfile!);
    debugPrint('Anonymous user service initialized');
  }
  
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);
      
      if (profileJson != null) {
        final profileData = json.decode(profileJson);
        _currentProfile = AnonymousUserProfile.fromMap(profileData);
        _profileController.add(_currentProfile!);
        debugPrint('Loaded anonymous profile: ${_currentProfile!.role} at ${_currentProfile!.company}');
      }
    } catch (e) {
      debugPrint('Error loading anonymous profile: $e');
    }
  }
  
  Future<void> _saveProfile() async {
    if (_currentProfile == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = json.encode(_currentProfile!.toMap());
      await prefs.setString(_profileKey, profileJson);
      
      debugPrint('Saved anonymous profile');
    } catch (e) {
      debugPrint('Error saving anonymous profile: $e');
    }
  }
  
  Future<void> refreshProfile() async {
    debugPrint('Refreshing anonymous profile from storage...');
    await _loadProfile();
    if (_currentProfile != null) {
      _profileController.add(_currentProfile!);
      debugPrint('Profile refreshed: ${_currentProfile!.role} at ${_currentProfile!.company}');
    }
  }
  
  Future<void> _createAnonymousProfile() async {
    final sessionId = _generateSessionId();
    final profile = AnonymousUserProfile(
      sessionId: sessionId,
      role: 'Software Engineer', // Default role for testing
      company: 'Tech Company', // Default company for testing
      preferences: {
        'privacy_mode': true,
        'show_anonymous': true,
        'auto_discover': true,
      },
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    
    _currentProfile = profile;
    await _saveProfile();
    _profileController.add(profile);
    
    debugPrint('Created new anonymous profile with session: $sessionId');
  }
  
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'anon_${timestamp}_$random';
  }
  
  Future<void> updateRole(String role) async {
    if (_currentProfile != null) {
      final updatedProfile = _currentProfile!.copyWith(role: role);
      _currentProfile = updatedProfile;
      await _saveProfile();
      _profileController.add(updatedProfile);
      debugPrint('Updated anonymous user role to: $role');
    }
  }
  
  Future<void> updateCompany(String company) async {
    if (_currentProfile != null) {
      final updatedProfile = _currentProfile!.copyWith(company: company);
      _currentProfile = updatedProfile;
      await _saveProfile();
      _profileController.add(updatedProfile);
      debugPrint('Updated anonymous user company to: $company');
    }
  }
  
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    if (_currentProfile != null) {
      final updatedProfile = _currentProfile!.copyWith(preferences: preferences);
      _currentProfile = updatedProfile;
      await _saveProfile();
      _profileController.add(updatedProfile);
      debugPrint('Updated anonymous user preferences');
    }
  }
  
  Future<void> updateLastActive() async {
    if (_currentProfile != null) {
      final updatedProfile = _currentProfile!.copyWith(lastActiveAt: DateTime.now());
      _currentProfile = updatedProfile;
      await _saveProfile();
      _profileController.add(updatedProfile);
    }
  }
  
  String getDisplayName() {
    if (_currentProfile == null) return 'Anonymous User';
    
    if (_currentProfile!.company != null) {
      return '${_currentProfile!.role} at ${_currentProfile!.company}';
    }
    return _currentProfile!.role;
  }
  
  String getShortDisplayName() {
    if (_currentProfile == null) return 'Anonymous';
    
    if (_currentProfile!.company != null) {
      return '${_currentProfile!.role} from ${_currentProfile!.company}';
    }
    return _currentProfile!.role;
  }
  
  Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_sessionIdKey);
      
      _currentProfile = null;
      await _createAnonymousProfile();
      
      debugPrint('Cleared anonymous profile and created new one');
    } catch (e) {
      debugPrint('Error clearing anonymous profile: $e');
    }
  }
  
  // Privacy service access - removed to break circular dependency
  
  Future<void> dispose() async {
    await _profileController.close();
  }
}

class AnonymousUserProfile {
  final String sessionId;
  final String role;
  final String? company;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  
  const AnonymousUserProfile({
    required this.sessionId,
    required this.role,
    this.company,
    required this.preferences,
    required this.createdAt,
    required this.lastActiveAt,
  });
  
  factory AnonymousUserProfile.fromMap(Map<String, dynamic> map) {
    return AnonymousUserProfile(
      sessionId: map['sessionId'] ?? '',
      role: map['role'] ?? 'Professional',
      company: map['company'],
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastActiveAt: DateTime.parse(map['lastActiveAt'] ?? DateTime.now().toIso8601String()),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'role': role,
      'company': company,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }
  
  AnonymousUserProfile copyWith({
    String? sessionId,
    String? role,
    String? company,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return AnonymousUserProfile(
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      company: company ?? this.company,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
  
  String get displayName {
    if (company != null) {
      return '$role at $company';
    }
    return role;
  }
  
  String get shortDisplayName {
    if (company != null) {
      return '$role from $company';
    }
    return role;
  }
  
  bool get isComplete {
    return role.isNotEmpty && company != null && company!.isNotEmpty;
  }
  
  @override
  String toString() {
    return 'AnonymousUserProfile(sessionId: $sessionId, role: $role, company: $company)';
  }
}
