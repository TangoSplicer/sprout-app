// src/components/USBSyncButton.jsx
import { useState } from 'react';
import { USBSync } from '../utils/usb-sync';

export default function USBSyncButton({ onAppImported }) {
  const [connected, setConnected] = useState(false);
  const sync = new USBSync();

  const handleConnect = async () => {
    try {
      const device = await sync.connect();
      setConnected(true);
      alert('Connected to Sprout mobile!');

      // List and import
      const files = await sync.listFiles(device);
      for (const file of files) {
        const app = await sync.importFile(device, file.name);
        if (app) onAppImported(app);
      }
    } catch (e) {
      alert('Connect failed: ' + e.message);
    }
  };

  return (
    <button onClick={handleConnect} disabled={connected}>
      {connected ? '✅ Connected' : '🔌 Connect via USB'}
    </button>
  );
}