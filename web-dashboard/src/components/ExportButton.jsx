// src/components/ExportButton.jsx
import { createSproutFile } from '../utils/sprout-builder';

export default function ExportButton({ app }) {
  const handleExport = async () => {
    try {
      const blob = await createSproutFile(app);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${app.name}.sprout`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      alert('Export failed: ' + e.message);
    }
  };

  return (
    <button onClick={handleExport} className="export-btn">
      📥 Export .sprout
    </button>
  );
}