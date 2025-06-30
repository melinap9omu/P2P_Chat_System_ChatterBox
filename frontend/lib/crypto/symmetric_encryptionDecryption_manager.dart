import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:pointycastle/export.dart' as pc;

class SymmetricEncryptionManager {
  static const int _aesKeySizeBits = 256;
  static const int _gcmIvLengthBytes = 16;

  static encrypt_lib.Key? _currentAesKey;

  static final pc.SecureRandom _secureRandom = _createSecureRandomForAES();

  static pc.SecureRandom _createSecureRandomForAES() {
    final pc.SecureRandom rnd = pc.FortunaRandom();
    final secureDartRandom = Random.secure();
    final Uint8List secureSeedBytes = Uint8List(32);
    for (int i = 0; i < secureSeedBytes.length; i++) {
      secureSeedBytes[i] = secureDartRandom.nextInt(256);
    }
    rnd.seed(pc.KeyParameter(secureSeedBytes));
    return rnd;
  }

  static String generateAesKeyBase64() {
    final Uint8List keyBytes = _secureRandom.nextBytes(_aesKeySizeBits ~/ 8);
    final key = encrypt_lib.Key(keyBytes);
    return key.base64;
  }

  static void setSharedAesKey(String aesKeyBase64) {
    _currentAesKey = encrypt_lib.Key.fromBase64(aesKeyBase64);
    print('Shared AES key set');
  }

  static String encrypt(String plainText) {
    if (_currentAesKey == null) {
      throw StateError("AES key not set. Perform key exchange first.");
    }
    try {
      final ivBytes = _secureRandom.nextBytes(_gcmIvLengthBytes);

      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(
          _currentAesKey!,
          mode: encrypt_lib.AESMode.gcm,
          padding: null,
        ),
      );

      final encrypted = encrypter.encrypt(plainText, iv: encrypt_lib.IV(ivBytes));

      final combinedBytes = Uint8List(_gcmIvLengthBytes + encrypted.bytes.length);
      combinedBytes.setRange(0, _gcmIvLengthBytes, ivBytes);
      combinedBytes.setRange(_gcmIvLengthBytes, combinedBytes.length, encrypted.bytes);

      return base64.encode(combinedBytes);
    } catch (e) {
      print('AES Encryption Error: $e');
      rethrow;
    }
  }

  static String decrypt(String encryptedTextBase64) {
    if (_currentAesKey == null) {
      throw StateError("AES key not set. Cannot decrypt");
    }
    try {
      final combinedBytes = base64.decode(encryptedTextBase64);
      if (combinedBytes.length < _gcmIvLengthBytes) {
        throw FormatException("Encrypted data too short to contain IV.");
      }

      final ivBytes = combinedBytes.sublist(0, _gcmIvLengthBytes);
      final encryptedBytes = combinedBytes.sublist(_gcmIvLengthBytes);

      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(
          _currentAesKey!,
          mode: encrypt_lib.AESMode.gcm,
          padding: null,
        ),
      );

      final decrypted = encrypter.decryptBytes(
        encrypt_lib.Encrypted(encryptedBytes),
        iv: encrypt_lib.IV(ivBytes),
      );

      return utf8.decode(decrypted);
    } catch (e) {
      print('AES Decryption Error: $e');
      rethrow;
    }
  }
}
