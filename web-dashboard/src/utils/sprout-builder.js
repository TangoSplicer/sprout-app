// src/utils/sprout-builder.js
import { ZipWriter, TextWriter, BlobWriter } from "zipjs";

export async function createSproutFile(app) {
  const zip = new ZipWriter(new BlobWriter());
  await zip.add("main.sprout", new TextWriter(app.content));
  // Add other files if needed
  return await zip.close();
}