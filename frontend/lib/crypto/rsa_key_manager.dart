import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/export.dart'; // Crucial and correct
import 'package:pointycastle/export.dart' as pc; // Alias also correct
import 'package:asn1lib/asn1lib.dart';
import '../crypto/rsa_encryptionDecryption_manager.dart'; // Your RSA encryption manager

pc.SecureRandom createSecureRandom() {
  final sr = pc.FortunaRandom();
  final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => math.Random.secure().nextInt(256)));
  sr.seed(pc.KeyParameter(seed));
  return sr;
}

class RsaKeyManager {
  static const _storage = FlutterSecureStorage();
  static const int _rsaKeySize = 2048;

  // Static helper methods to create user-specific storage keys
  static String _getPrivateKeyStorageKey(int userId) =>
      'rsa_private_key_pkcs8_base64_$userId';
  static String _getPublicKeyStorageKey(int userId) =>
      'rsa_public_key_x509_base64_$userId';

  // The init method is still a placeholder for general manager readiness
  static Future<void> init() async {
    print("RsaKeyManager initialized.");
  }

  static Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>?>
  getStorageKey(int userId) async {
    print("=== RETRIEVING KEY PAIR FOR USER $userId ===");

    final privateKeyStorageKey = _getPrivateKeyStorageKey(userId);
    final publicKeyStorageKey = _getPublicKeyStorageKey(userId);

    // First, check if keys exist in storage
    String? privateKeyBase64 = await _storage.read(key: privateKeyStorageKey);
    String? publicKeyBase64 = await _storage.read(key: publicKeyStorageKey);

    print("Storage check results:");
    print("- Private key exists: ${privateKeyBase64 != null}");
    print("- Public key exists: ${publicKeyBase64 != null}");

    if (privateKeyBase64 != null) {
      print("- Private key length: ${privateKeyBase64.length}");
      print("- Private key preview: ${privateKeyBase64}");
    }
    if (publicKeyBase64 != null) {
      print("- Public key length: ${publicKeyBase64.length}");
      print("- Public key preview: ${publicKeyBase64}");
    }

    if (privateKeyBase64 != null && publicKeyBase64 != null) {
      print('Attempting to retrieve existing RSA key pair for user $userId from secure storage.');

      try {
        print("Decoding public key from X509 Base64...");
        final publicKey = RsaKeyConverter.decodePublicKeyFromX509Base64(publicKeyBase64);

        print("Decoding private key from PKCS8 Base64...");
        final privateKey = RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(privateKeyBase64);

        if (privateKey != null && publicKey != null) {
          print("✓ Successfully decoded both keys from storage");

          // Validate that the key pair matches by testing encryption/decryption
          final keyPairValid = _validateKeyPairWithEncryption(publicKey, privateKey);
          if (keyPairValid) {
            print("✓ Key pair validation successful");
            return pc.AsymmetricKeyPair(publicKey, privateKey);
          } else {
            print("❌ Key pair validation failed - keys don't match");
            print("Will regenerate key pair...");
            // Delete corrupted keys and regenerate
            await _storage.delete(key: privateKeyStorageKey);
            await _storage.delete(key: publicKeyStorageKey);
          }
        } else {
          print('❌ Failed to decode keys from storage:');
          print('  - Private key decoded: ${privateKey != null}');
          print('  - Public key decoded: ${publicKey != null}');
          // Delete corrupted keys
          await _storage.delete(key: privateKeyStorageKey);
          await _storage.delete(key: publicKeyStorageKey);
        }
      } catch (e) {
        print('❌ Error decoding stored keys for user $userId: $e');
        // Delete corrupted keys
        await _storage.delete(key: privateKeyStorageKey);
        await _storage.delete(key: publicKeyStorageKey);
      }
    }
   return null;
  }

  static Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>>
  generateNewKeyPair(int userId) async {
    try {
       await clearKeysForUser(userId);
      final rsaGen = pc.RSAKeyGenerator();
      final keyParams = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), _rsaKeySize, 64);
      rsaGen.init(pc.ParametersWithRandom(keyParams, createSecureRandom()));

      final keyPair = rsaGen.generateKeyPair();
      final rsaPublicKey = keyPair.publicKey as pc.RSAPublicKey;
      final rsaPrivateKey = keyPair.privateKey as pc.RSAPrivateKey;

       final privateKeyStorageKey = _getPrivateKeyStorageKey(userId);
       final publicKeyStorageKey = _getPublicKeyStorageKey(userId);
      print("Generated key pair details:");
      print("- Public key modulus bits: ${rsaPublicKey.modulus?.bitLength}");
      print("- Private key modulus bits: ${rsaPrivateKey.modulus?.bitLength}");
      print("- Public exponent: ${rsaPublicKey.exponent}");
      print("- Private exponent: ${rsaPublicKey.exponent}");


      // Validate the generated key pair before storing
      if (!_validateKeyPairWithEncryption(rsaPublicKey, rsaPrivateKey)) {
        throw StateError('Generated key pair validation failed!');
      }

      // Encode keys to Base64
      final generatedPrivateKeyBase64 = RsaKeyConverter.encodePrivateKeyToPkcs8Base64(rsaPrivateKey);
      final generatedPublicKeyBase64 = RsaKeyConverter.encodePublicKeyToX509Base64(rsaPublicKey);

      print("Encoded key lengths:");
      print("- Private key Base64 length: ${generatedPrivateKeyBase64.length}");
      print("- Public key Base64 length: ${generatedPublicKeyBase64.length}");

      // Store the keys
      await _storage.write(key: privateKeyStorageKey, value: generatedPrivateKeyBase64);
      await _storage.write(key: publicKeyStorageKey, value: generatedPublicKeyBase64);

      // Verify storage by reading back and decoding
      final storedPrivateKey = await _storage.read(key: privateKeyStorageKey);
      final storedPublicKey = await _storage.read(key: publicKeyStorageKey);

      print("Storage verification:");
      print("- Private key stored successfully: ${storedPrivateKey != null}");
      print("- Public key stored successfully: ${storedPublicKey != null}");
      print("- Private key matches: ${storedPrivateKey == generatedPrivateKeyBase64}");
      print("- Public key matches: ${storedPublicKey == generatedPublicKeyBase64}");

      // Verify we can decode them back correctly
      final decodedPrivateKey = RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(generatedPrivateKeyBase64);
      final decodedPublicKey = RsaKeyConverter.decodePublicKeyFromX509Base64(generatedPublicKeyBase64);

      if (decodedPrivateKey == null || decodedPublicKey == null) {
        throw StateError('Failed to decode newly generated keys!');
      }

      if (!_validateKeyPairWithEncryption(decodedPublicKey, decodedPrivateKey)) {
        throw StateError('Decoded key pair validation failed!');
      }

      print('✓ New RSA key pair generated, stored, and validated successfully for user $userId.');
      return pc.AsymmetricKeyPair(rsaPublicKey, rsaPrivateKey);

    } catch (e) {
      print('❌ Error generating new key pair for user $userId: $e');
      rethrow;
    }
  }

  static Future<pc.RSAPublicKey?> getPublicKey(int userId) async {
    print("=== RETRIEVING PUBLIC KEY FOR USER $userId ===");

    try {
      final publicKeyBase64 = await _storage.read(key: _getPublicKeyStorageKey(userId));
      print("Public key retrieval:");
      print("- Storage key: ${_getPublicKeyStorageKey(userId)}");
      print("- Key exists in storage: ${publicKeyBase64 != null}");

      if (publicKeyBase64 != null) {
        print("- Key length: ${publicKeyBase64.length}");
        final publicKey = RsaKeyConverter.decodePublicKeyFromX509Base64(publicKeyBase64);
        print("- Decode successful: ${publicKey != null}");
        if (publicKey != null) {
          print("- Modulus bits: ${publicKey.modulus?.bitLength}");
          print("- Exponent: ${publicKey.exponent}");
        }
        return publicKey;
      } else {
        print("❌ No public key found in storage for user $userId");
        return null;
      }
    } catch (e) {
      print("❌ Error retrieving public key for user $userId: $e");
      return null;
    }
  }

  static Future<pc.RSAPrivateKey?> getPrivateKey(int userId) async {
    print("=== RETRIEVING PRIVATE KEY FOR USER $userId ===");

    try {
      final privateKeyBase64 = await _storage.read(
          key: _getPrivateKeyStorageKey(userId));
      if (privateKeyBase64 != null) {
        RsaKeyConverter.debugPrivateKey(privateKeyBase64);
      }

      print("Private key retrieval:");
      print("- Storage key: ${_getPrivateKeyStorageKey(userId)}");
      print("- Key exists in storage: ${privateKeyBase64 != null}");

      if (privateKeyBase64 != null) {
        print("- Key length: ${privateKeyBase64.length}");
        final privateKey = RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(
            privateKeyBase64)!;
        print("- Decode successful: ${privateKey != null}");
        if (privateKey != null) {
          print("- Modulus bits: ${privateKey.modulus?.bitLength}");

        }

        return privateKey;
      } else {
        print("❌ No private key found in storage for user $userId");
        print("Available storage keys:");
        final allKeys = await _storage.readAll();
        for (final key in allKeys.keys) {
          if (key.contains('rsa_private_key')) {
            print("  - $key");
          }
        }
        return null;
      }
    } catch (e) {
      print("❌ Error retrieving private key for user $userId: $e");
      return null;
    }
  }
  static pc.RSAPublicKey? decodeRemotePublicKeyFromX509Base64(String x509Base64) {
    return RsaKeyConverter.decodePublicKeyFromX509Base64(x509Base64);
  }

  static bool _validateKeyPairWithEncryption(pc.RSAPublicKey publicKey, pc.RSAPrivateKey privateKey) {
    try {
      print("=== VALIDATING KEY PAIR WITH ENCRYPTION TEST ===");
      print("Public key - modulus bits: ${publicKey.modulus?.bitLength}, exponent: ${publicKey.exponent}");
      print("Private key - modulus bits: ${privateKey.modulus?.bitLength}, exponent: ${publicKey.exponent}");

      // Check if modulus matches
      if (publicKey.modulus != privateKey.modulus) {
        print("❌ Key pair validation failed: modulus mismatch");
        return false;
      }

      // The proper validation is to encrypt with public key and decrypt with private key
      try {
        const testMessage = "test_key_validation_123";

        // Use your existing encryption/decryption methods
        final encrypted = RsaEncryptionManager.encryptWithPublicKey(testMessage, publicKey);
        final decrypted = RsaEncryptionManager.decryptWithPrivateKey(encrypted, privateKey);

        final isValid = decrypted == testMessage;
        print("Encryption test result: ${isValid ? 'PASSED' : 'FAILED'}");

        if (isValid) {
          print("✓ Key pair validation successful");
        } else {
          print("❌ Key pair validation failed: encryption/decryption test failed");
          print("Expected: '$testMessage'");
          print("Got: '$decrypted'");
        }

        return isValid;

      } catch (e) {
        print("❌ Key pair validation failed during encryption test: $e");
        return false;
      }

    } catch (e) {
      print("❌ Key pair validation failed with error: $e");
      return false;
    }
  }

  // Method to ensure keys exist for a user
  static Future<bool> ensureKeysExist(int userId) async {
    print("=== ENSURING KEYS EXIST FOR USER $userId ===");

    try {

      await getStorageKey(userId);

      // Verify both keys can be retrieved
      final publicKey = await getPublicKey(userId);
      final privateKey = await getPrivateKey(userId);

      final keysExist = publicKey != null && privateKey != null;
      print("Keys existence verification: ${keysExist ? 'SUCCESS' : 'FAILED'}");

      if (keysExist) {
        final keyPairValid = _validateKeyPairWithEncryption(publicKey, privateKey!);
        print("Key pair validation: ${keyPairValid ? 'SUCCESS' : 'FAILED'}");
        return keyPairValid;
      }

      return false;
    } catch (e) {
      print("❌ Error ensuring keys exist for user $userId: $e");
      return false;
    }
  }

  static Future<void> debugStorageState(int userId) async {
    print("=== DEBUG STORAGE STATE FOR USER $userId ===");

    try {
      final allKeys = await _storage.readAll();
      print("All storage keys (${allKeys.length} total):");

      for (final entry in allKeys.entries) {
        if (entry.key.contains(userId.toString())) {
          print("  - ${entry.key}");
        }
      }

      final privateKeyExists = allKeys.containsKey(_getPrivateKeyStorageKey(userId));
      final publicKeyExists = allKeys.containsKey(_getPublicKeyStorageKey(userId));

      print("User $userId key status:");
      print("  - Private key exists: $privateKeyExists");
      print("  - Public key exists: $publicKeyExists");

      if (privateKeyExists) {
        final privateKey = await getPrivateKey(userId);
        print("  - Private key decode successful: ${privateKey != null}");
      }

      if (publicKeyExists) {
        final publicKey = await getPublicKey(userId);
        print("  - Public key decode successful: ${publicKey != null}");
      }

    } catch (e) {
      print("❌ Error debugging storage state: $e");
    }
  }

  // Method to clear all keys for a user (useful for testing)
  static Future<void> clearKeysForUser(int userId) async {
    print("=== CLEARING KEYS FOR USER $userId ===");
    await _storage.delete(key: _getPrivateKeyStorageKey(userId));
    await _storage.delete(key: _getPublicKeyStorageKey(userId));
    print("✓ Keys cleared for user $userId");
  }
}

class RsaKeyConverter {
  // Simple RSA OID for encoding (we only need this for creating keys)
  static final ASN1ObjectIdentifier rsaEncryptionOid =
  ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1');

  static String encodePublicKeyToX509Base64(pc.RSAPublicKey publicKey) {
    final rsaPublicKeySeq = ASN1Sequence();
    rsaPublicKeySeq.add(ASN1Integer(publicKey.modulus!));
    rsaPublicKeySeq.add(ASN1Integer(publicKey.exponent!));

    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(rsaEncryptionOid);
    algorithmSeq.add(ASN1Null());

    final bitString =
    ASN1BitString(Uint8List.fromList(rsaPublicKeySeq.encodedBytes));

    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(bitString);

    final derBytes = Uint8List.fromList(topLevelSeq.encodedBytes);

    return base64.encode(derBytes);
  }

  static pc.RSAPublicKey? decodePublicKeyFromX509Base64(String x509Base64) {
    try {
      final derBytes = base64.decode(x509Base64);
      final ASN1Sequence topLevelSeq = ASN1Sequence.fromBytes(derBytes);

      if (topLevelSeq.elements.length != 2 ||
          (topLevelSeq.elements[0] is! ASN1Sequence) ||
          (topLevelSeq.elements[1] is! ASN1BitString)) {
        throw FormatException(
            'Invalid X.509 SubjectPublicKeyInfo top-level structure.');
      }

      final ASN1Sequence algorithmSeq = topLevelSeq.elements[0] as ASN1Sequence;

      // Check if algorithm sequence has elements
      if (algorithmSeq.elements.isEmpty) {
        throw FormatException('Empty algorithm identifier sequence.');
      }

      // Skip OID validation entirely - just extract the key data
      final ASN1BitString bitString = topLevelSeq.elements[1] as ASN1BitString;

      final ASN1Sequence rsaPublicKeySeq =
      ASN1Sequence.fromBytes(bitString.contentBytes());

      if (rsaPublicKeySeq.elements.length != 2 ||
          (rsaPublicKeySeq.elements[0] is! ASN1Integer) ||
          (rsaPublicKeySeq.elements[1] is! ASN1Integer)) {
        throw FormatException(
            'Invalid RSA Public Key structure inside BitString.');
      }

      final BigInt modulus =
          (rsaPublicKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
      final BigInt publicExponent =
          (rsaPublicKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;

      if (modulus <= BigInt.zero || publicExponent <= BigInt.zero) {
        throw FormatException('Invalid RSA key parameters');
      }

      print(
          'Successfully decoded RSA public key: ${modulus.bitLength} bits, exponent: $publicExponent');
      return pc.RSAPublicKey(modulus, publicExponent);
    } catch (e) {
      print('Error decoding public key from X.509 Base64: $e');
      return null;
    }
  }

  static void debugPublicKey(String x509Base64) {
    try {
      final derBytes = base64.decode(x509Base64);
      final ASN1Sequence topLevelSeq = ASN1Sequence.fromBytes(derBytes);

      print('=== DEBUG PUBLIC KEY STRUCTURE ===');
      print('Top level sequence elements: ${topLevelSeq.elements.length}');

      // Try to extract the actual RSA key regardless of OID
      if (topLevelSeq.elements.length >= 2 && topLevelSeq.elements[1] is ASN1BitString) {
        final ASN1BitString bitString = topLevelSeq.elements[1] as ASN1BitString;
        try {
          final ASN1Sequence rsaKeySeq = ASN1Sequence.fromBytes(bitString.contentBytes());
          if (rsaKeySeq.elements.length == 2 &&
              rsaKeySeq.elements[0] is ASN1Integer &&
              rsaKeySeq.elements[1] is ASN1Integer) {
            final BigInt modulus = (rsaKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
            final BigInt exponent = (rsaKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;
            print('✓ Valid RSA key structure found:');
            print('  Modulus bits: ${modulus.bitLength}');
            print('  Exponent: $exponent');
          }
        } catch (e) {
          print('✗ Failed to parse RSA key structure: $e');
        }
      }
      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  static void debugPrivateKey(String base64Key) {
    try {
      final derBytes = base64.decode(base64Key);
      final topLevelSeq = ASN1Sequence.fromBytes(derBytes);

      print('=== DEBUG PRIVATE KEY STRUCTURE ===');
      print('Top level sequence elements: ${topLevelSeq.elements.length}');

      // Detect PKCS#8 by structure (3 elements, second is SEQUENCE, third is OCTET STRING)
      if (topLevelSeq.elements.length == 3 &&
          topLevelSeq.elements[0] is ASN1Integer &&
          topLevelSeq.elements[1] is ASN1Sequence &&
          topLevelSeq.elements[2] is ASN1OctetString) {
        print('Detected: PKCS#8 private key format.');

        final pkcs1BytesList = (topLevelSeq.elements[2] as ASN1OctetString).valueBytes();
        // FIX: Convert List<int> to Uint8List
        final Uint8List pkcs1Bytes = Uint8List.fromList(pkcs1BytesList);

        _debugPkcs1(pkcs1Bytes);
      }
      // Detect PKCS#1 directly (9 integers)
      else if (topLevelSeq.elements.length == 9 &&
          topLevelSeq.elements.every((e) => e is ASN1Integer)) {
        print('Detected: PKCS#1 private key format.');
        _debugPkcs1(derBytes);
      } else {
        print('✗ Unrecognized private key structure.');
      }

      print('=== END DEBUG ===');
    } on ASN1Exception catch (e) {
      print('✗ ASN.1 parsing failed: $e');
    } catch (e) {
      print('✗ Debug error: $e');
    }
  }

  static void _debugPkcs1(Uint8List derBytes) { // FIX: Change parameter type to Uint8List
    try {
      final seq = ASN1Sequence.fromBytes(derBytes);
      if (seq.elements.length != 9 || !seq.elements.every((e) => e is ASN1Integer)) {
        print('✗ Invalid PKCS#1 structure.');
        return;
      }

      final version = seq.elements[0] as ASN1Integer;
      final modulus = seq.elements[1] as ASN1Integer;
      final publicExponent = seq.elements[2] as ASN1Integer;
      final privateExponent = seq.elements[3] as ASN1Integer;
      final prime1 = seq.elements[4] as ASN1Integer;
      final prime2 = seq.elements[5] as ASN1Integer;
      final exponent1 = seq.elements[6] as ASN1Integer;
      final exponent2 = seq.elements[7] as ASN1Integer;
      final coefficient = seq.elements[8] as ASN1Integer;

      print('  Version: ${version.valueAsBigInteger}');
      print('  Modulus bits: ${modulus.valueAsBigInteger.bitLength}');
      print('  Public Exponent: ${publicExponent.valueAsBigInteger}');
      print('  Private Exponent bits: ${privateExponent.valueAsBigInteger.bitLength}');
      print('  Prime 1 bits: ${prime1.valueAsBigInteger.bitLength}');
      print('  Prime 2 bits: ${prime2.valueAsBigInteger.bitLength}');
      print('  Exponent 1 bits: ${exponent1.valueAsBigInteger.bitLength}');
      print('  Exponent 2 bits: ${exponent2.valueAsBigInteger.bitLength}');
      print('  Coefficient bits: ${coefficient.valueAsBigInteger.bitLength}');
    } catch (e) {
      print('✗ Failed to parse PKCS#1: $e');
    }
  }

  static String encodePrivateKeyToPkcs8Base64(pc.RSAPrivateKey privateKey) {
    // Create the PKCS#1 RSA Private Key structure
    final pkcs1PrivateKeySeq = ASN1Sequence();
    pkcs1PrivateKeySeq.add(ASN1Integer(BigInt.from(0))); // version
    pkcs1PrivateKeySeq.add(ASN1Integer(privateKey.modulus!)); // modulus (n)
    pkcs1PrivateKeySeq.add(ASN1Integer(BigInt.from(65537))); // publicExponent (e) - Use standard value
    pkcs1PrivateKeySeq.add(ASN1Integer(privateKey.exponent!)); // privateExponent (d)
    pkcs1PrivateKeySeq.add(ASN1Integer(privateKey.p!)); // prime1
    pkcs1PrivateKeySeq.add(ASN1Integer(privateKey.q!)); // prime2

    // Calculate exponent1 (d mod (p-1))
    final exponent1 = privateKey.exponent! % (privateKey.p! - BigInt.one);
    pkcs1PrivateKeySeq.add(ASN1Integer(exponent1));

    // Calculate exponent2 (d mod (q-1))
    final exponent2 = privateKey.exponent! % (privateKey.q! - BigInt.one);
    pkcs1PrivateKeySeq.add(ASN1Integer(exponent2));

    // Calculate coefficient (q^-1 mod p)
    final coefficient = privateKey.q!.modInverse(privateKey.p!);
    pkcs1PrivateKeySeq.add(ASN1Integer(coefficient));

    // Algorithm identifier sequence
    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(rsaEncryptionOid);
    algorithmSeq.add(ASN1Null());

    final octetStringPrivateKey = ASN1OctetString(
        Uint8List.fromList(pkcs1PrivateKeySeq.encodedBytes));

    final pkcs8Seq = ASN1Sequence();
    pkcs8Seq.add(ASN1Integer(BigInt.from(0))); // version
    pkcs8Seq.add(algorithmSeq);
    pkcs8Seq.add(octetStringPrivateKey);

    final derBytes = Uint8List.fromList(pkcs8Seq.encodedBytes);
    return base64.encode(derBytes);
  }

  static pc.RSAPrivateKey? decodePrivateKeyFromPkcs8Base64(String keyBase64) {
    try {
      final derBytes = base64.decode(keyBase64);
      final asn1 = ASN1Parser(derBytes);
      final topLevelSeq = asn1.nextObject() as ASN1Sequence;

      // PKCS#8: 3 elements (version, algorithm identifier, private key octet string)
      if (topLevelSeq.elements.length == 3 &&
          topLevelSeq.elements[2] is ASN1OctetString) {
        print("Detected PKCS#8 private key");
        final octetString = topLevelSeq.elements[2] as ASN1OctetString;
        return _decodePkcs1(octetString.octets);
      }

      // PKCS#1: directly starts with modulus, exponent, etc.
      print("Detected PKCS#1 private key");
      return _decodePkcs1(derBytes);
    } catch (e) {
      print("❌ Error decoding private key: $e");
      return null;
    }
  }

  static pc.RSAPrivateKey? _decodePkcs1(Uint8List bytes) {
    try {
      final seq = ASN1Sequence.fromBytes(bytes);
      if (seq.elements.length != 9) {
        throw FormatException("Invalid PKCS#1 structure — expected 9 elements");
      }

      final modulus = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
      final publicExponent = (seq.elements[2] as ASN1Integer).valueAsBigInteger;
      final privateExponent = (seq.elements[3] as ASN1Integer).valueAsBigInteger;
      final p = (seq.elements[4] as ASN1Integer).valueAsBigInteger;
      final q = (seq.elements[5] as ASN1Integer).valueAsBigInteger;

      print("✅ Decoded PKCS#1: modulus bits = ${modulus.bitLength}");
      return pc.RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      print("❌ Error decoding PKCS#1: $e");
      return null;
    }
  }

}
