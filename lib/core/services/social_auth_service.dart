import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SocialAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // Google Sign In
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create/update user profile
      if (userCredential.user != null) {
        await _createOrUpdateProfile(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      
      rethrow;
    }
  }
  
  // Apple Sign In (iOS only)
  static Future<UserCredential?> signInWithApple() async {
    try {
      // Apple Sign In requires iOS setup and the sign_in_with_apple package
      // For now, we'll show a message that it's not available
      throw UnimplementedError('Apple Sign In requires iOS setup and additional configuration');
    } catch (e) {
      
      rethrow;
    }
  }
  
  // Twitter Sign In (requires Twitter Developer setup)
  static Future<UserCredential?> signInWithTwitter() async {
    try {
      // Twitter OAuth requires Twitter Developer account and app configuration
      throw UnimplementedError('Twitter sign-in requires Twitter Developer setup');
    } catch (e) {
      
      rethrow;
    }
  }
  
  // LinkedIn Sign In (requires LinkedIn Developer setup)
  static Future<UserCredential?> signInWithLinkedIn() async {
    try {
      // LinkedIn OAuth requires LinkedIn Developer account and app configuration
      throw UnimplementedError('LinkedIn sign-in requires LinkedIn Developer setup');
    } catch (e) {
      
      rethrow;
    }
  }
  
  // Helper method to create or update user profile
  static Future<void> _createOrUpdateProfile(User user) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('profiles').doc(user.uid);
      final doc = await userDoc.get();
      
      if (!doc.exists) {
        // Create new profile
        await userDoc.set({
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'authProvider': user.providerData.first.providerId,
        });
        
        // Create initial availability status
        await FirebaseFirestore.instance
            .collection('availability')
            .doc(user.uid)
            .set({
          'isAvailable': false,
          'audience': 'firstDegree',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create initial referral data
        await FirebaseFirestore.instance
            .collection('referrals')
            .doc(user.uid)
            .set({
          'credits': 0,
          'invitedCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing profile
        await userDoc.update({
          'updatedAt': FieldValue.serverTimestamp(),
          'authProvider': user.providerData.first.providerId,
        });
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error updating user profile: $e');
    }
  }
  
  // Sign out from all providers
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      
      rethrow;
    }
  }
}
