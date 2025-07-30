// src/utils/e2ee.js
// Browser version using Web Crypto API
export class E2EE {
  async generateKeyPair() {
    return await crypto.subtle.generateKey(
      { name: "ECDH", namedCurve: "P-256" },
      true,
      ["deriveKey", "deriveBits"]
    );
  }

  async exportPublicKey(key) {
    const raw = await crypto.subtle.exportKey("raw", key);
    return btoa(String.fromCharCode(...new Uint8Array(raw)));
  }

  async importPublicKey(pem) {
    const binary = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
    return await crypto.subtle.importKey(
      "raw",
      binary,
      { name: "ECDH", namedCurve: "P-256" },
      true,
      []
    );
  }

  async encrypt(plaintext, publicKey) {
    const enc = new TextEncoder();
    const data = enc.encode(plaintext);

    const aesKey = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, ["encrypt"]);
    const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv: crypto.getRandomValues(new Uint8Array(12)) }, aesKey, data);

    const exportedKey = await crypto.subtle.exportKey("jwk", aesKey);
    const encryptedKey = await this._encryptKeyWithECDH(exportedKey, publicKey);

    return {
      nonce: btoa(String.fromCharCode(...new Uint8Array(12))),
      key: encryptedKey,
      data: btoa(String.fromCharCode(...new Uint8Array(encrypted)))
    };
  }

  async _encryptKeyWithECDH(aesJwk, publicKey) {
    // In real app: use ECDH to wrap AES key
    return aesJwk;
  }
}