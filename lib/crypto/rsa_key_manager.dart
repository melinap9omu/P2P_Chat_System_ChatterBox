import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/export.dart'; // Crucial and correct
import 'package:pointycastle/export.dart' as pc; // Alias also correct
import 'package:asn1lib/asn1lib.dart';


pc.SecureRandom createSecureRandom() {
  final sr = pc.FortunaRandom();
  final seed =Uint8List.fromList(
      List<int>.generate(32,(_)=> Random.secure().nextInt(256))
  );
  sr.seed(pc.KeyParameter(seed));
  return sr;
}

class RsaKeyManager {
  static const _storage = FlutterSecureStorage();
  // Removed fixed storage keys
  static const int _rsaKeySize = 2048;

  // Static helper methods to create user-specific storage keys
 static String _getPrivateKeyStorageKey(String userId) =>
    'rsa_private_key_pkcs8_base64_$userId';

static String _getPublicKeyStorageKey(String userId) =>
    'rsa_public_key_x509_base64_$userId';

  // The init method is still a placeholder for general manager readiness
  static Future<void> init() async {
    print("RsaKeyManager initialized.");
    // No user-specific logic here, as userId is not available globally at this stage
  }


  static Future<String?> getPublicKeyX509Base64(String userId) async {
    return await _storage.read(key: _getPublicKeyStorageKey(userId));
  }

  // Read stored private key (decoded)
 // Modified to be user-specific
 static Future<pc.RSAPrivateKey?> getPrivateKey(String userId) async {
  final privateKeyBase64 = await _storage.read(key: _getPrivateKeyStorageKey(userId));
  return privateKeyBase64 != null
      ? RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(privateKeyBase64)
      : null;
}



  // Modified to be user-specific
 static Future<void> generateKeyPairIfNotExist(String userId) async {
  final hasKey = await getPublicKeyX509Base64(userId);
  if (hasKey != null) {
    print('RSA key already exists for user $userId');
    return;
  }

  final rsaGen = pc.RSAKeyGenerator();
  final keyParams = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), _rsaKeySize, 64);
  rsaGen.init(pc.ParametersWithRandom(keyParams, createSecureRandom()));
  final keyPair = rsaGen.generateKeyPair();

  final rsaPublicKey = keyPair.publicKey as pc.RSAPublicKey;
  final rsaPrivateKey = keyPair.privateKey as pc.RSAPrivateKey;

  final generatedPrivateKeyBase64 = RsaKeyConverter.encodePrivateKeyToPkcs8Base64(rsaPrivateKey);
  final generatedPublicKeyBase64 = RsaKeyConverter.encodePublicKeyToX509Base64(rsaPublicKey);

  await _storage.write(key: _getPrivateKeyStorageKey(userId), value: generatedPrivateKeyBase64);
  await _storage.write(key: _getPublicKeyStorageKey(userId), value: generatedPublicKeyBase64);

  print('New RSA key pair generated and stored for user $userId');
}

  // This method remains unchanged as it's for decoding *remote* public keys (which don't belong to the current user)
  static pc.RSAPublicKey? decodeRemotePublicKeyFromX509Base64(String x509Base64) {
    return RsaKeyConverter.decodePublicKeyFromX509Base64(x509Base64);
  }
}

// RsaKeyConverter class remains unchanged as you provided it.
class RsaKeyConverter {
  static final ASN1ObjectIdentifier rsaEncryptionOid = ASN1ObjectIdentifier(
      [1, 2, 840, 113549, 1, 1, 1]);

  static String encodePublicKeyToX509Base64(pc.RSAPublicKey publicKey) {
    final rsaPublicKeySeq = ASN1Sequence();
    rsaPublicKeySeq.add(ASN1Integer(publicKey.n!));
    rsaPublicKeySeq.add(ASN1Integer(publicKey.exponent!));

    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(rsaEncryptionOid);
    algorithmSeq.add(ASN1Null());

    final bitString = ASN1BitString(
        Uint8List.fromList(rsaPublicKeySeq.encodedBytes));

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
            'Invalid X.509 SubjectPublicKeyInfor top-level structure.');
      }
      final ASN1Sequence algorithmSeq = topLevelSeq.elements[0] as ASN1Sequence;
      final ASN1ObjectIdentifier oid = algorithmSeq
          .elements[0] as ASN1ObjectIdentifier;
      if (oid.identifier != rsaEncryptionOid.identifier) {
        throw FormatException('Algorithm OID mismatch: Not RSA');
      }
      final ASN1BitString bitString = topLevelSeq.elements[1] as ASN1BitString;

      final ASN1Sequence rsaPublicKeySeq = ASN1Sequence.fromBytes(
          bitString.contentBytes());

      if (rsaPublicKeySeq.elements.length != 2 ||
          (rsaPublicKeySeq.elements[0] is! ASN1Integer) ||
          (rsaPublicKeySeq.elements[1] is! ASN1Integer)) {
        throw FormatException(
            'Invalid RSA Public Key structure inside  BitString.');
      }
      final BigInt modulus = (rsaPublicKeySeq.elements[0] as ASN1Integer)
          .valueAsBigInteger;
      final BigInt publicExponent = (rsaPublicKeySeq.elements[1] as ASN1Integer)
          .valueAsBigInteger;
      return pc.RSAPublicKey(modulus, publicExponent);
    }
    catch (e) {
      print('Error decoding public Key from X.509 Base64: $e ');
      return null;
    }
  }

  static String encodePrivateKeyToPkcs8Base64(pc.RSAPrivateKey privateKey) {
    final pkcs1PrivateKySeq = ASN1Sequence();
    pkcs1PrivateKySeq.add(ASN1Integer(BigInt.from(0)));
    pkcs1PrivateKySeq.add(ASN1Integer(privateKey.n!));
    pkcs1PrivateKySeq.add(ASN1Integer(privateKey.exponent!));
    pkcs1PrivateKySeq.add(ASN1Integer(privateKey.d!));
    pkcs1PrivateKySeq.add(ASN1Integer(privateKey.p!));
    pkcs1PrivateKySeq.add(ASN1Integer(
        privateKey.privateExponent! % (privateKey.p! - BigInt.one)));
    pkcs1PrivateKySeq.add(ASN1Integer(
        privateKey.privateExponent! % (privateKey.q! - BigInt.one)));
    pkcs1PrivateKySeq.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(rsaEncryptionOid);
    algorithmSeq.add(ASN1Null());

    final octetStringPrivateKey = ASN1OctetString(
        Uint8List.fromList(pkcs1PrivateKySeq.encodedBytes));

    final pkcs8Seq = ASN1Sequence();
    pkcs8Seq.add(ASN1Integer(BigInt.from(0)));
    pkcs8Seq.add(algorithmSeq);
    pkcs8Seq.add(octetStringPrivateKey);

    final derBytes = Uint8List.fromList(pkcs8Seq.encodedBytes);
    return base64.encode(derBytes);
  }

  static pc.RSAPrivateKey? decodePrivateKeyFromPkcs8Base64(String pkcs8Base64){
    try{
      final derBytes = base64.decode(pkcs8Base64);
      final ASN1Sequence pkcs8Seq = ASN1Sequence.fromBytes(derBytes);

      if (pkcs8Seq.elements.length != 3 || (pkcs8Seq.elements[1] is! ASN1Sequence) || (pkcs8Seq.elements[2] is! ASN1OctetString)) {
        throw FormatException('Invalid PKCS#8 PrivateKeyInfo top-level structure.');
      }

      final ASN1OctetString octerStringPrivateKey = pkcs8Seq.elements[2] as ASN1OctetString;

      // Parse the inner PKCS#1 RSA Private Key sequence
      final ASN1Sequence rsaPrivateKeyPkcs1Seq = ASN1Sequence.fromBytes(octerStringPrivateKey.contentBytes());

      if (rsaPrivateKeyPkcs1Seq.elements.length != 9 || (rsaPrivateKeyPkcs1Seq.elements[1] is! ASN1Integer)) {
        throw FormatException('Invalid PKCS#1 RSA Private Key structure inside OctetString.');
      }

      final BigInt modulus = (rsaPrivateKeyPkcs1Seq.elements[1] as ASN1Integer).valueAsBigInteger;
      final BigInt privateExponent = (rsaPrivateKeyPkcs1Seq.elements[3] as ASN1Integer).valueAsBigInteger;
      final BigInt prime1 = (rsaPrivateKeyPkcs1Seq.elements[4] as ASN1Integer).valueAsBigInteger;
      final BigInt prime2 = (rsaPrivateKeyPkcs1Seq.elements[5] as ASN1Integer).valueAsBigInteger;
      return pc.RSAPrivateKey(modulus, privateExponent, prime1, prime2);
    } catch (e) {
      print('Error decoding private key from PKCS#8 Base64: $e');
      return null;
    }
  }
}