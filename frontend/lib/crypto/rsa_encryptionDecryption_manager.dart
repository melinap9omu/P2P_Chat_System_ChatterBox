import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/api.dart';
import '../crypto/rsa_key_manager.dart'; // Your RSA encryption manager

// Note: The following imports are not used in this class and can be removed
// if they are not needed elsewhere.
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart';

/// Manages RSA encryption and decryption operations.
class RsaEncryptionManager {
  /// Encrypts a string with a public key using PKCS1 padding.
  static String encryptWithPublicKey(String plainText, pc.RSAPublicKey publicKey) {
    try {
      print("Starting RSA encryption using pkcs1encoding");
      final inputBytes = Uint8List.fromList(utf8.encode(plainText));

      // Use PKCS1Encoding to add padding
      final encryptor = pc.PKCS1Encoding(pc.RSAEngine());
      try {
        encryptor.init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));
      } catch (e) {
        print("Unable to encrypt using pkcs1encoding");
      }
      print("Usee public key${publicKey}");
      final encryptedBytes = encryptor.process(inputBytes);
      return base64.encode(encryptedBytes);
    } catch (e) {
      print('RSA Encryption Error: $e');
      rethrow;
    }finally{
      print("Usee public key${publicKey}");

    }
  }

  /// Decrypts a base64 encoded string with a private key using PKCS1 padding.
  static String decryptWithPrivateKey(String encryptedTextBase64, pc.RSAPrivateKey privateKey) {
    // The outer try-catch block is essential to handle any errors during the
    // entire decryption process, such as malformed base64 strings.
    try {
      print("=== RSA DECRYPTION DEBUG START ===");
      final inputBytes = base64.decode(encryptedTextBase64);
      print("Input bytes length: ${inputBytes.length}");
      print("Private key modulus bit length: ${privateKey.modulus?.bitLength}");
      print("Expected cipher text length: ${(privateKey.modulus?.bitLength ?? 0) ~/ 8}");

      // Verify input length matches key size
      final expectedLength = (privateKey.modulus?.bitLength ?? 0) ~/ 8;
      if (inputBytes.length != expectedLength) {
        throw ArgumentError('Invalid ciphertext length: ${inputBytes.length}, expected: $expectedLength');
      }


      // Print first few bytes to debug block type
      print("First 4 bytes of encrypted data: ${inputBytes.take(4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");

      // Create decryptor with proper error handling
      final decryptor = pc.PKCS1Encoding(pc.RSAEngine());


      try {
        decryptor.init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
        print("✓ Decryptor initialized successfully");
      } catch (e) {
        print("❌ Decryptor initialization failed: $e");
        throw StateError('Failed to initialize RSA decryptor: $e');
      }

      // Attempt decryption
      try {
        final decryptedBytes = decryptor.process(inputBytes);
        final result = utf8.decode(decryptedBytes);
        print("✓ Decryption successful, result length: ${result.length}");
        print("=== RSA DECRYPTION DEBUG END ===");
        return result;
      } catch (e) {
        print("❌ Decryption process failed: $e");
        rethrow; // Re-throw the error so the outer catch can handle it
      }
    } catch (e) {
      print('RSA Decryption Error: $e');
      rethrow;
    }
  }

  /// Verifies if a given public and private key pair match by encrypting and decrypting
  /// a test message.
  static bool verifyKeyPairMatch(pc.RSAPublicKey publicKey, pc.RSAPrivateKey privateKey) {
    try {
      // Test encryption/decryption with a simple message
      const testMessage = "test_key_pair_match";

      print("Testing key pair match...");
      print("Public key modulus: ${publicKey.modulus?.bitLength} bits");
      print("Private key modulus: ${privateKey.modulus?.bitLength} bits");

      // Check if modulus matches
      if (publicKey.modulus != privateKey.modulus) {
        print("❌ Key pair mismatch: Different modulus");
        return false;
      }

      // Test actual encryption/decryption
      final encrypted = encryptWithPublicKey(testMessage, publicKey);
      final decrypted = decryptWithPrivateKey(encrypted, privateKey);

      final matches = decrypted == testMessage;
      print(matches ? "✓ Key pair matches" : "❌ Key pair mismatch");
      return matches;

    } catch (e) {
      print("❌ Key pair verification failed: $e");
      return false;
    }
  }
}
