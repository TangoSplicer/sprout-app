// src/components/EncryptedExport.jsx
import { useState } from 'react';
import { E2EE } from '../utils/e2ee';

export default function EncryptedExport({ app }) {
  const [publicKey, setPublicKey] = useState('');
  const [encrypted, setEncrypted] = useState(null);

  const handleEncrypt = async () => {
    const e2ee = new E2EE();
    const key = await e2ee.importPublicKey(publicKey);
    const encryptedData = await e2ee.encrypt(app.content, key);
    setEncrypted(encryptedData);
  };

  return (
    <div className="encrypted-export">
      <input
        placeholder="Paste public key"
        value={publicKey}
        onChange={(e) => setPublicKey(e.target.value)}
      />
      <button onClick={handleEncrypt}>Encrypt & Export</button>
      {encrypted && (
        <pre>{JSON.stringify(encrypted, null, 2)}</pre>
      )}
    </div>
  );
}