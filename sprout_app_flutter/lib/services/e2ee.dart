import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts project payloads with an ephemeral P-256 ECDH key exchange and
/// AES-256-GCM. The encoded envelope carries the ephemeral public key, nonce,
/// and authenticated ciphertext required by the recipient to decrypt it.
class E2EE {
  static final E2EE _instance = E2EE._internal();
  static final ECDomainParameters _domain = ECDomainParameters('secp256r1');

  factory E2EE() => _instance;

  E2EE._internal();

  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
    final random = FortunaRandom();
    random.seed(KeyParameter(_secureBytes(32)));

    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(_domain),
          random,
        ),
      );

    return generator.generateKeyPair()
        as AsymmetricKeyPair<ECPublicKey, ECPrivateKey>;
  }

  Future<String> encrypt(String plaintext, ECPublicKey recipientKey) async {
    final ephemeral = generateKeyPair();
    final sharedSecret =
        _deriveSharedSecret(ephemeral.privateKey, recipientKey);
    final encryptionKey = _deriveEncryptionKey(sharedSecret);
    final nonce = _secureBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(encryptionKey), 128, nonce, Uint8List(0)),
      );

    final ciphertext =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final point = ephemeral.publicKey.Q!;

    return jsonEncode({
      'version': 1,
      'ephemeralX': base64Encode(_bigIntToBytes(point.x!.toBigInteger()!, 32)),
      'ephemeralY': base64Encode(_bigIntToBytes(point.y!.toBigInteger()!, 32)),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
    });
  }

  /// Decrypts an envelope produced by [encrypt]. [senderKey] is retained for
  /// source compatibility with the earlier API; the envelope's authenticated
  /// ephemeral key is the key material used for decryption.
  Future<String> decrypt(
    String encryptedEnvelope,
    ECPrivateKey recipientKey,
    ECPublicKey senderKey,
  ) async {
    final decoded = jsonDecode(encryptedEnvelope);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported encrypted Sprout envelope');
    }

    final x = _bytesToBigInt(base64Decode(decoded['ephemeralX'] as String));
    final y = _bytesToBigInt(base64Decode(decoded['ephemeralY'] as String));
    final point = _domain.curve.createPoint(x, y);
    final ephemeralPublicKey = ECPublicKey(point, _domain);
    final sharedSecret = _deriveSharedSecret(recipientKey, ephemeralPublicKey);
    final encryptionKey = _deriveEncryptionKey(sharedSecret);
    final nonce = base64Decode(decoded['nonce'] as String);
    final ciphertext = base64Decode(decoded['ciphertext'] as String);

    if (nonce.length != 12) {
      throw const FormatException('Invalid AES-GCM nonce');
    }

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(encryptionKey), 128, nonce, Uint8List(0)),
      );

    try {
      return utf8.decode(cipher.process(ciphertext));
    } on InvalidCipherTextException {
      throw const FormatException(
          'Encrypted Sprout envelope failed authentication');
    }
  }

  Uint8List _deriveSharedSecret(
      ECPrivateKey privateKey, ECPublicKey publicKey) {
    final agreement = ECDHBasicAgreement()..init(privateKey);
    final secret = agreement.calculateAgreement(publicKey);
    return _bigIntToBytes(secret, 32);
  }

  Uint8List _deriveEncryptionKey(Uint8List sharedSecret) =>
      SHA256Digest().process(sharedSecret);

  Uint8List _secureBytes(int length) {
    final secureRandom = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => secureRandom.nextInt(256)),
    );
  }

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    return Uint8List.fromList(
      List<int>.generate(
        length,
        (index) =>
            int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
      ),
    );
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    return BigInt.parse(
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
  }
}
