// src/components/QRScanner.jsx
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';

export default function QRScanner({ onScan }) {
  const [scanning, setScanning] = useState(true);
  const [error, setError] = useState('');
  const videoRef = useRef(null);

  useEffect(() => {
    if (!scanning) return;

    const constraints = {
      video: { facingMode: 'environment' }
    };

    navigator.mediaDevices.getUserMedia(constraints)
      .then(stream => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
      })
      .catch(err => {
        setError('Camera access denied. Use mobile app instead.');
        console.error('Camera error:', err);
      });

    const scanInterval = setInterval(() => {
      if (!videoRef.current) return;

      const canvas = document.createElement('canvas');
      const video = videoRef.current;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext('2d').drawImage(video, 0, 0);

      const imageData = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
      const code = scanQR(imageData); // Simplified QR decode

      if (code && code.startsWith('SPROUT:')) {
        const appId = code.replace('SPROUT:', '');
        onScan({ id: appId, name: `Imported App ${appId}` });
        setScanning(false);
      }
    }, 500);

    return () => clearInterval(scanInterval);
  }, [scanning, onScan]);

  // Simplified QR decode (in real app: use jsQR or zxing)
  function scanQR(imageData) {
    // Placeholder: in real app, use jsQR library
    return null;
  }

  return (
    <div className="qr-scanner">
      {error ? (
        <p className="error">{error}</p>
      ) : (
        <>
          <video ref={videoRef} autoPlay playsInline style={{ width: '100%', maxHeight: '300px', borderRadius: '12px' }} />
          {scanning ? (
            <p>Scanning... 🕵️‍♂️</p>
          ) : (
            <p>✅ App imported!</p>
          )}
        </>
      )}
      <button onClick={() => setScanning(false)}>Close</button>
    </div>
  );
}

// Helper: use jsQR in real app
// import jsQR from "jsqr";