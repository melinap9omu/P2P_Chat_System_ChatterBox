import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

class RsaEncryptionManager {
  static String encryptWithPublicKey(String plainText, pc.RSAPublicKey publicKey) {
    try {
      final inputBytes = Uint8List.fromList(utf8.encode(plainText));

      final encryptor = pc.RSAEngine()
        ..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));

      final encryptedBytes = encryptor.process(inputBytes);
      return base64.encode(encryptedBytes);
    } catch (e) {
      print('RSA Encryption Error: $e');
      rethrow;
    }
  }

  static String decryptWithPrivateKey(String encryptedTextBase64, pc.RSAPrivateKey privateKey) {
    try {
      final inputBytes = base64.decode(encryptedTextBase64);

      final decryptor = pc.RSAEngine()
        ..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));

      final decryptedBytes = decryptor.process(inputBytes);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      print('RSA Decryption Error: $e');
      rethrow;
    }
  }
}
