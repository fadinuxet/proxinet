import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'putrace_crypto_service.dart';
import 'putrace_secure_store.dart';
import 'simple_firebase_monitor.dart';

/// Professional Authentication Service - Privacy-first approach for professional networking
/// Features:
/// - No phone number required (professional email only)
/// - Professional identity separate from personal
/// - End-to-end encryption key generation
/// - Professional domain verification
class ProfessionalAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final PutraceCryptoService _cryptoService;
  final PutraceSecureStore _secureStore;
  
  ProfessionalAuthService(this._cryptoService, this._secureStore);

  /// Create professional identity without phone number (Privacy-first)
  Future<ProfessionalIdentity> createProfessionalIdentity({
    required String professionalEmail,
    required String displayName,
    String? company,
    String? title,
    List<String> skills = const [],
    PrivacyLevel privacyLevel = PrivacyLevel.professional,
  }) async {
    try {
      // Verify professional email domain
      await _verifyProfessionalEmail(professionalEmail);
      
      // Generate professional identity hash (for privacy)
      final identityId = _cryptoService.createProfessionalIdentityHash(professionalEmail);
      
      // Generate encryption key pair for end-to-end encryption
      final keyPair = await _cryptoService.generateProfessionalKeyPair();
      
      // Create professional identity
      final identity = ProfessionalIdentity(
        identityId: identityId,
        displayName: displayName,
        professionalEmail: professionalEmail,
        company: company,
        title: title,
        skills: skills,
        privacyLevel: privacyLevel,
        createdAt: DateTime.now(),
        isVerified: false, // Will be verified through email
        encryptionPublicKey: keyPair.publicKey,
        identityType: IdentityType.professional,
      );
      
      // Store identity locally (encrypted)
      await _secureStore.storeProfessionalIdentity(identity.toMap());
      
      // Store public information in Firestore (private key never leaves device)
      await _storeProfessionalIdentitySecurely(identity);
      
      // Track creation event
      SimpleFirebaseMonitor.trackPutraceEvent('professional_identity_created', {
        'has_company': company != null,
        'has_title': title != null,
        'skills_count': skills.length,
        'privacy_level': privacyLevel.name,
      });
      
      return identity;
    } catch (e) {
      throw Exception('Failed to create professional identity: $e');
    }
  }
  
  /// Authenticate with professional email only (no phone required)
  Future<UserCredential> signInWithProfessionalEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Load professional identity
      final identity = await getProfessionalIdentity();
      if (identity == null) {
        throw Exception('No professional identity found. Please create one first.');
      }
      
      // Track sign in event
      SimpleFirebaseMonitor.trackPutraceEvent('professional_signin', {
        'auth_method': 'email_password',
        'has_identity': true,
      });
      
      return credential;
    } catch (e) {
      throw Exception('Failed to sign in with professional email: $e');
    }
  }
  
  /// Create account with professional email (no phone required)
  Future<UserCredential> createAccountWithProfessionalEmail({
    required String email,
    required String password,
    required String displayName,
    String? company,
    String? title,
  }) async {
    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      
      // Create professional identity
      await createProfessionalIdentity(
        professionalEmail: email,
        displayName: displayName,
        company: company,
        title: title,
      );
      
      // Send email verification
      await credential.user?.sendEmailVerification();
      
      // Track account creation
      SimpleFirebaseMonitor.trackPutraceEvent('professional_account_created', {
        'auth_method': 'email_password',
        'email_domain': email.split('@').last,
        'has_company': company != null,
        'has_title': title != null,
      });
      
      return credential;
    } catch (e) {
      throw Exception('Failed to create professional account: $e');
    }
  }
  
  /// Get stored professional identity
  Future<ProfessionalIdentity?> getProfessionalIdentity() async {
    try {
      final identityMap = await _secureStore.getProfessionalIdentity();
      if (identityMap != null) {
        return ProfessionalIdentity.fromMap(identityMap);
      }
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Update professional identity
  Future<void> updateProfessionalIdentity(ProfessionalIdentity updatedIdentity) async {
    try {
      // Store locally
      await _secureStore.storeProfessionalIdentity(updatedIdentity.toMap());
      
      // Update in Firestore
      await _storeProfessionalIdentitySecurely(updatedIdentity);
      
      // Track update event
      SimpleFirebaseMonitor.trackPutraceEvent('professional_identity_updated', {
        'identity_type': updatedIdentity.identityType.name,
        'privacy_level': updatedIdentity.privacyLevel.name,
      });
    } catch (e) {
      throw Exception('Failed to update professional identity: $e');
    }
  }
  
  /// Verify professional email domain
  Future<bool> _verifyProfessionalEmail(String email) async {
    // Check if email is from professional domain
    final domain = email.split('@').last.toLowerCase();
    
    // List of common personal email domains to avoid
    const personalDomains = [
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'icloud.com',
      'aol.com',
      'protonmail.com',
    ];
    
    if (personalDomains.contains(domain)) {
        // Allow with warning for MVP, but recommend professional email
        SimpleFirebaseMonitor.trackPutraceEvent('personal_email_used', {
          'domain': domain,
          'warning_shown': true,
        });
      return true; // Allow for now, but show warning in UI
    }
    
    // Professional domain - preferred
    SimpleFirebaseMonitor.trackPutraceEvent('professional_email_used', {
      'domain': domain,
    });
    
    return true;
  }
  
  /// Store professional identity securely (public info only)
  Future<void> _storeProfessionalIdentitySecurely(ProfessionalIdentity identity) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      // Store only public information (encryption keys stored locally)
      final publicData = {
        'identityId': identity.identityId,
        'displayName': identity.displayName,
        'professionalEmail': identity.professionalEmail,
        'company': identity.company,
        'title': identity.title,
        'skills': identity.skills,
        'privacyLevel': identity.privacyLevel.name,
        'createdAt': identity.createdAt,
        'isVerified': identity.isVerified,
        'encryptionPublicKey': identity.encryptionPublicKey, // Public key is safe to store
        'identityType': identity.identityType.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('professional_identities')
          .doc(user.uid)
          .set(publicData);
          
            // Increment write count for monitoring
            SimpleFirebaseMonitor.trackWrite();
    } catch (e) {
      throw Exception('Failed to store professional identity: $e');
    }
  }
  
  /// Get professional identity from Firestore
  Future<ProfessionalIdentity?> getProfessionalIdentityFromCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore
          .collection('professional_identities')
          .doc(user.uid)
          .get();
          
            // Increment read count for monitoring
            SimpleFirebaseMonitor.trackRead();
      
      if (doc.exists && doc.data() != null) {
        return ProfessionalIdentity.fromMap(doc.data()!);
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Sign out and clear professional identity
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // Option to keep professional identity locally or clear it
      // For privacy, we'll keep it unless user explicitly wants to clear
      
      SimpleFirebaseMonitor.trackPutraceEvent('professional_signout', {
        'identity_preserved': true,
      });
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
  
  /// Clear all professional data (for complete logout)
  Future<void> clearProfessionalData() async {
    try {
      await _secureStore.clearAll();
      
      SimpleFirebaseMonitor.trackPutraceEvent('professional_data_cleared', {
        'reason': 'user_request',
      });
    } catch (e) {
      throw Exception('Failed to clear professional data: $e');
    }
  }
  
  /// Check if user has professional identity
  Future<bool> hasProfessionalIdentity() async {
    final identity = await getProfessionalIdentity();
    return identity != null;
  }
  
  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  /// Stream of auth state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
