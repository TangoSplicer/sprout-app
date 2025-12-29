// src/utils/sprout-builder.js

export async function createSproutFile(app) {
  // Simplified implementation for MVP
  // In production, use jszip or similar library
  const blob = new Blob([app.content], { type: 'text/plain' });
  return blob;
}