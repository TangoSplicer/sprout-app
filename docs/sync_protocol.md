# Sprout Sync Protocol

## Overview
Secure, end-to-end encrypted sync between Sprout mobile and web dashboard.

- Works offline
- No central server required
- E2EE by default
- Supports USB, QR, Wi-Fi Direct

## Sync Flow

### Option 1: QR Code (Recommended)
1. Web dashboard generates **encrypted QR** with app data + ephemeral key
2. Mobile scans QR → decrypts → imports
3. Mobile signs confirmation → shows QR
4. Web scans confirmation → marks sync complete

### Option 2: USB
1. Connect phone via USB
2. Web app detects as WebUSB device
3. Exchange ephemeral keys
4. Encrypt and transfer `.sprout` files
5. Verify checksums

### Option 3: Wi-Fi Direct (Future)
1. Mobile and web on same network
2. Discover via mDNS
3. TLS-like handshake with E2EE
4. Transfer files

## Data Format