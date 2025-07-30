// src/components/Header.jsx
import USBSyncButton from './USBSyncButton';

export default function Header({ onScanClick }) {
  return (
    <header>
      <div className="logo">
        <span>🌱</span>
        <h1>Sprout Garden</h1>
      </div>
      <p>Your apps, grown by you.</p>
      <USBSyncButton onAppImported={console.log} />
    </header>
  );
}