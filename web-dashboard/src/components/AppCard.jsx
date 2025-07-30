// src/components/AppCard.jsx
import ExportButton from './ExportButton';

export default function AppCard({ app, onDelete }) {
  return (
    <div className="app-card">
      <h3>{app.name}</h3>
      <p>{app.screens.length} screens</p>
      <p><small>Created {new Date(app.createdAt).toLocaleDateString()}</small></p>
      <div className="card-actions">
        <ExportButton app={app} />
        <button onClick={() => onDelete(app.id)}>Delete</button>
      </div>
    </div>
  );
}