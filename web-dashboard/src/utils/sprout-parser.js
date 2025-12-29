// src/utils/sprout-parser.js

// Parse .sprout file (simplified for MVP)
export async function parseSproutFile(buffer, fileName) {
  try {
    const text = new TextDecoder().decode(buffer);

    // Simple parse: extract app name from main.sprout
    const nameMatch = text.match(/app\s+"([^"]+)"/);
    const appName = nameMatch ? nameMatch[1] : fileName.replace('.sprout', '');

    // Count screens
    const screenMatches = [...text.matchAll(/screen\s+(\w+)/g)];
    const screens = screenMatches.map(m => m[1]);

    return {
      id: Date.now().toString(),
      name: appName,
      screens,
      createdAt: Date.now(),
      content: text,
    };
  } catch (e) {
    console.error("Failed to parse .sprout file", e);
    return null;
  }
}