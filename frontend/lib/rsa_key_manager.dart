import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/export.dart'; // THIS LINE IS CRUCIAL AND SHOULD RESOLVE IT

import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';


pc.SecureRandom createSecureRandom() {
  final sr = pc.FortunaRandom();
  final seed =Uint8List.fromList(
    List<int>.generate(32,(_)=> Random.secure().nextInt(256))
  );
  sr.seed(pc.KeyParameter(seed));
  return sr;
}
class RsaKeyManager{
  static const _storage =FlutterSecureStorage();
  static const _privateKeyStorageKey = 'rsa_private_key_pkcs8_base64';
  static const _publicKeyStorageKey = 'rsa_public_key_x509_base64';
  static const int _rsaKeySize = 2048;

  static Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>> generateOrGetRSAKeyPair() async{
    String? privateKeyBASe64 = await _storage.read(key: _privateKeyStorageKey);
    String? publicKeyBAse64 = await _storage.read(key: _publicKeyStorageKey);

    if (privateKeyBASe64 != null && publicKeyBAse64!=null){
      print('Retrieved existing  RSA pair form secure storage.');
      final privateKey = RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(privateKeyBASe64);
      final publicKey = RsaKeyConverter.decodePublicKeyFromX509Base64(publicKeyBAse64);

      if (privateKey!=null && publicKey!=null){
        return pc.AsymmetricKeyPair(publicKey, privateKey);
      }
      else{
        print('Stored keys are corrupted, regenrating.');
        await _storage.delete(key: _privateKeyStorageKey);
        await _storage.delete(key: _publicKeyStorageKey);
      }

    }
    print('Generating new RSA key pair and storing in secure storage.');

    final rsaGen = pc.RSAKeyGenerator();
    final keyParams = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), _rsaKeySize,64);

    rsaGen.init(pc.ParametersWithRandom(keyParams, createSecureRandom()));

    final keyPair = rsaGen.generateKeyPair();
    final rsaPublicKey = keyPair.publicKey as pc.RSAPublicKey;
    final rsaPrivateKey = keyPair.privateKey as pc.RSAPrivateKey;

    final generatedPrivateKeyBase64 = RsaKeyConverter.encodePrivateKeyToPkcs8Base64(rsaPrivateKey);
    final generatedPublicKeyBase64 = RsaKeyConverter.encodePublicKeyToX509Base64(rsaPublicKey);

    await _storage.write(key: _privateKeyStorageKey, value: generatedPrivateKeyBase64);
    await _storage.write(key: _publicKeyStorageKey, value: generatedPublicKeyBase64);

    print('New RSA key pair generated and stored successfully.');
    return pc.AsymmetricKeyPair(rsaPublicKey,rsaPrivateKey );

  }
  static Future<String?> getPublicKeyX509Base64() async {
    return await _storage.read(key: _publicKeyStorageKey);
  }
  static Future<pc.RSAPrivateKey?> getPrivateKey() async {
    final privateKeyBase64 = await _storage.read(key: _privateKeyStorageKey);
    return privateKeyBase64 != null ? RsaKeyConverter.decodePrivateKeyFromPkcs8Base64(privateKeyBase64) : null;
  }
  static pc.RSAPublicKey? decodeRemotePublicKeyFromX509Base64(String x509Base64) {
    return RsaKeyConverter.decodePublicKeyFromX509Base64(x509Base64);
  }



}

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
      return pc.RSAPrivateKey(modulus, privateExponent, prime1, prime2); // Return pc.RSAPrivateKey
    } catch (e) {
      print('Error decoding private key from PKCS#8 Base64: $e');
      return null;
    }
  }





}