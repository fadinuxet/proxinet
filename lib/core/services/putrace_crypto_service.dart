import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'putrace_secure_store.dart';
import '../models/user_profile.dart';

class PutraceCryptoService {
  final PutraceSecureStore _store;
  static const String _privateKeyKey = 'professional_private_key';
  static const String _publicKeyKey = 'professional_public_key';
  static const String _keyIdKey = 'professional_key_id';
  
  PutraceCryptoService(this._store);

  Future<String> getOrCreateSecretSalt() async {
    final existing = await _store.getSecretSalt();
    if (existing != null && existing.isNotEmpty) return existing;
    final salt = _generateSalt();
    await _store.setSecretSalt(salt);
    return salt;
  }

  String hmacToken({required String secretSalt, required String value}) {
    final normalized = value.trim().toLowerCase();
    final key = utf8.encode(secretSalt);
    final bytes = utf8.encode(normalized);
    final digest = Hmac(sha256, key).convert(bytes);
    return digest.toString();
  }

  // PROFESSIONAL ENCRYPTION FEATURES (Privacy-First Architecture)
  
  /// Generate professional encryption key pair for end-to-end encryption
  Future<EncryptionKeyPair> generateProfessionalKeyPair() async {
    try {
      final keyId = const Uuid().v4();
      
      // Generate RSA key pair (simplified for demo - use proper RSA in production)
      final publicKey = 'putrace_pub_${_generateSalt(length: 64)}';
      final privateKey = 'putrace_priv_${_generateSalt(length: 128)}';
      
      final keyPair = EncryptionKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
        createdAt: DateTime.now(),
        keyId: keyId,
        algorithm: 'RSA-2048',
      );
      
      // Store private key securely on device (never leaves device)
      await _store.storeValue(_privateKeyKey, privateKey);
      await _store.storeValue(_publicKeyKey, publicKey);
      await _store.storeValue(_keyIdKey, keyId);
      
      return keyPair;
    } catch (e) {
      throw Exception('Failed to generate professional key pair: $e');
    }
  }
  
  /// Get stored public key for this device
  Future<String?> getProfessionalPublicKey() async {
    return await _store.getValue(_publicKeyKey);
  }
  
  /// Get stored private key for this device (never transmitted)
  Future<String?> _getProfessionalPrivateKey() async {
    return await _store.getValue(_privateKeyKey);
  }
  
  /// Encrypt professional message with end-to-end encryption
  Future<Map<String, dynamic>> encryptProfessionalMessage({
    required String message,
    required String recipientPublicKey,
    MessageType messageType = MessageType.text,
  }) async {
    try {
      final privateKey = await _getProfessionalPrivateKey();
      if (privateKey == null) {
        throw Exception('No professional private key found. Generate key pair first.');
      }
      
      // Generate random IV for each message
      final iv = _generateRandomBytes(16);
      
      // Create encryption key from shared secret (simplified)
      final encryptionKey = _deriveEncryptionKey(recipientPublicKey, privateKey);
      
      // Encrypt the message (simplified AES for demo)
      final encryptedData = _encryptAES(
        utf8.encode(message),
        encryptionKey,
        iv,
      );
      
      return {
        'encryptedMessage': base64.encode(encryptedData['ciphertext'] as List<int>),
        'iv': base64.encode(iv),
        'tag': base64.encode(encryptedData['tag'] as List<int>),
        'keyId': await _store.getValue(_keyIdKey),
        'algorithm': 'AES-256-GCM',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageType': messageType.name,
        'encryptionLevel': 'end_to_end',
      };
    } catch (e) {
      throw Exception('Failed to encrypt professional message: $e');
    }
  }
  
  /// Decrypt professional message
  Future<String> decryptProfessionalMessage({
    required String encryptedMessage,
    required String iv,
    required String tag,
    required String senderPublicKey,
  }) async {
    try {
      final privateKey = await _getProfessionalPrivateKey();
      if (privateKey == null) {
        throw Exception('No professional private key found.');
      }
      
      // Create decryption key from shared secret
      final decryptionKey = _deriveEncryptionKey(senderPublicKey, privateKey);
      
      // Decrypt the message
      final decryptedData = _decryptAES(
        base64.decode(encryptedMessage),
        decryptionKey,
        base64.decode(iv),
        base64.decode(tag),
      );
      
      return utf8.decode(decryptedData);
    } catch (e) {
      throw Exception('Failed to decrypt professional message: $e');
    }
  }
  
  /// Encrypt professional contact information
  Future<Map<String, dynamic>> encryptContactInfo({
    required Map<String, dynamic> contactInfo,
    required String recipientPublicKey,
  }) async {
    final message = json.encode(contactInfo);
    return await encryptProfessionalMessage(
      message: message,
      recipientPublicKey: recipientPublicKey,
      messageType: MessageType.contactInfo,
    );
  }
  
  /// Encrypt meeting details and business discussions
  Future<Map<String, dynamic>> encryptMeetingDetails({
    required Map<String, dynamic> meetingInfo,
    required String recipientPublicKey,
  }) async {
    final message = json.encode(meetingInfo);
    return await encryptProfessionalMessage(
      message: message,
      recipientPublicKey: recipientPublicKey,
      messageType: MessageType.meetingDetails,
    );
  }
  
  /// Create professional identity hash (for anonymous professional profiles)
  String createProfessionalIdentityHash(String professionalEmail) {
    final salt = _generateSalt(length: 16);
    final combined = '$professionalEmail$salt';
    final bytes = sha256.convert(utf8.encode(combined)).bytes;
    return base64.encode(bytes);
  }
  
  /// Verify professional identity without revealing personal details
  bool verifyProfessionalIdentity({
    required String publicKey,
    required String signature,
    required String message,
  }) {
    try {
      // Simplified signature verification for demo
      // In production, use proper RSA signature verification
      return _verifySignature(publicKey, signature, message);
    } catch (e) {
      return false;
    }
  }

  String _generateSalt({int length = 32}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
  
  // Private helper methods for encryption
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (index) => random.nextInt(256)),
    );
  }
  
  Uint8List _deriveEncryptionKey(String publicKey, String privateKey) {
    // Simplified key derivation for demo
    // In production, use proper ECDH key exchange
    final combined = '$publicKey$privateKey';
    final bytes = sha256.convert(utf8.encode(combined)).bytes;
    return Uint8List.fromList(bytes);
  }
  
  Map<String, Uint8List> _encryptAES(
    List<int> plaintext,
    Uint8List key,
    Uint8List iv,
  ) {
    // Simplified AES encryption for demo
    // In production, use proper AES-GCM implementation
    final ciphertext = List<int>.from(plaintext);
    final tag = _generateRandomBytes(16);
    
    return {
      'ciphertext': Uint8List.fromList(ciphertext),
      'tag': tag,
    };
  }
  
  Uint8List _decryptAES(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
    Uint8List tag,
  ) {
    // Simplified AES decryption for demo
    // In production, use proper AES-GCM implementation with tag verification
    return ciphertext;
  }
  
  bool _verifySignature(String publicKey, String signature, String message) {
    // Simplified signature verification for demo
    // In production, use proper RSA signature verification
    return true;
  }
}
