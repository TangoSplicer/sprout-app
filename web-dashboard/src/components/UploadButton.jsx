// src/components/UploadButton.jsx
import { useState } from 'react';
import { parseSproutFile } from '../utils/sprout-parser';

export default function UploadButton({ onAppUploaded }) {
  const [dragActive, setDragActive] = useState(false);

  const handleChange = async (e) => {
    e.preventDefault();
    const file = e.target.files?.[0];
    if (file) {
      await handleFile(file);
    }
  };

  const handleFile = async (file) => {
    const arrayBuffer = await file.arrayBuffer();
    const app = await parseSproutFile(arrayBuffer, file.name);
    if (app) {
      onAppUploaded(app);
    }
  };

  const onDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const onDrop = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    const file = e.dataTransfer.files?.[0];
    if (file) {
      await handleFile(file);
    }
  };

  return (
    <label className={`upload-btn ${dragActive ? "drag-active" : ""}`}
           onDragEnter={onDrag}
           onDragLeave={onDrag}
           onDragOver={onDrag}
           onDrop={onDrop}>
      <input type="file" accept=".sprout" onChange={handleChange} />
      📤 Import .sprout File
    </label>
  );
}