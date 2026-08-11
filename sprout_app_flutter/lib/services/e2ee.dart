
---

End-to-End Encryption (E2EE)

Encrypt `.sprout` files so only **you** can read them.

### 📄 `flutter/lib/services/e2ee.dart`
```dart
// flutter/lib/services/e2ee.dart
import 'dart:convert';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/params/ec_key_params.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/key_generators/ec_key_generator.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/stream/chacha.dart';

class E2EE {
  static final E2EE _instance = E2EE._internal();
  factory E2EE() => _instance;
  E2EE._internal();

  // Generate user key pair (stored in secure storage)
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
    final keyGen = ECKeyGenerator('secp256r1');
    keyGen.init(ParametersWithRandom(null, SecureRandom('Fortuna')));
    return keyGen.generateKeyPair();
  }

  // Encrypt data with shared secret
  Future<String> encrypt(String plaintext, ECPublicKey theirPubKey) async {
    final myKeyPair = generateKeyPair();
    final secret = _deriveSharedSecret(myKeyPair.privateKey, theirPubKey);

    final nonce = _randomBytes(24); // XChaCha20 needs 24-byte nonce
    final cipher = StreamCipher('XChaCha20-Poly1305')..init(true, ParametersWithIV(KeyParameter(secret), nonce));

    final encrypted = cipher.process(utf8.encode(plaintext));
    final combined = [...nonce, ...encrypted];

    return base64Encode(combined);
  }

  // Decrypt data
  Future<String> decrypt(String encryptedBase64, ECPrivateKey myPrivKey, ECPublicKey theirPubKey) async {
    final encrypted = base64Decode(encryptedBase64);
    final nonce = encrypted.sublist(0, 24);
    final ciphertext = encrypted.sublist(24);

    final secret = _deriveSharedSecret(myPrivKey, theirPubKey);
    final cipher = StreamCipher('XChaCha20-Poly1305')..init(false, ParametersWithIV(KeyParameter(secret), nonce));

    final decrypted = cipher.process(ciphertext);
    return utf8.decode(decrypted);
  }

  // Derive shared secret (ECDH)
  Uint8List _deriveSharedSecret(ECPrivateKey myPriv, ECPublicKey theirPub) {
    final ec = ECCurve_secp256r1();
    final P = theirPub.Q;
    final d = myPriv.d;
    final S = P * d.value;
    final hash = SHA256Digest().process(S.x.toBytes());
    return hash;
  }

  Uint8List _randomBytes(int len) {
    final random = SecureRandom('Fortuna')..seed(KeyParameter(utf8.encode(DateTime.now().millisecondsSinceEpoch.toString())));
    return random.nextBytes(len);
  }
}