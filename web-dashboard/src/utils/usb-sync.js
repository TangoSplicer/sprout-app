// src/utils/usb-sync.js
import { parseSproutFile } from './sprout-parser.js';
export class USBSync {
  async connect() {
    if (!navigator.usb) {
      throw new Error("WebUSB not supported in this browser");
    }

    try {
      const device = await navigator.usb.requestDevice({ filters: [] });
      await device.open();
      await device.selectConfiguration(1);
      await device.claimInterface(0);
      return device;
    } catch (e) {
      throw new Error("Failed to connect: " + e.message);
    }
  }

  async listFiles(device) {
    // In real app: read from device storage
    return [
      { name: 'Plant Care.sprout', size: 1024 },
      { name: 'My To-Do.sprout', size: 2048 }
    ];
  }

  async importFile(device, fileName) {
    // Simulate read
    const response = await fetch(`/usb/${fileName}`);
    const arrayBuffer = await response.arrayBuffer();
    return await parseSproutFile(arrayBuffer, fileName);
  }

  async exportFile(device, app) {
    const blob = new Blob([app.content], { type: 'application/octet-stream' });
    const file = new File([blob], `${app.name}.sprout`, { type: 'application/sprout' });

    // In real app: write to device
    console.log('Exported:', file.name);
    return true;
  }
}