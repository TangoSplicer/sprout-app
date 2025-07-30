// src/App.jsx
import { useEffect, useState } from 'react';
import Header from './components/Header';
import AppCard from './components/AppCard';
import UploadButton from './components/UploadButton';
import QRScanner from './components/QRScanner';
import useSproutApps from './hooks/useSproutApps';
import './style/index.css';

function App() {
  const { apps, addApp, deleteApp } = useSproutApps();
  const [showScanner, setShowScanner] = useState(false);

  return (
    <div className="app">
      <Header onScanClick={() => setShowScanner(true)} />

      <main>
        <div className="upload-row">
          <UploadButton onAppUploaded={addApp} />
          <button className="scan-btn" onClick={() => setShowScanner(true)}>
            🧭 Scan QR Code
          </button>
        </div>

        {apps.length === 0 ? (
          <div className="empty-state">
            <p>No apps yet. Import your first .sprout file.</p>
          </div>
        ) : (
          <div className="app-grid">
            {apps.map((app) => (
              <AppCard key={app.id} app={app} onDelete={deleteApp} />
            ))}
          </div>
        )}
      </main>

      {showScanner && (
        <div className="modal">
          <div className="modal-content">
            <h3>Scan QR Code</h3>
            <QRScanner onScan={addApp} />
            <button onClick={() => setShowScanner(false)}>Close</button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;