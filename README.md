# Sprout: Grow apps that grow with you.

Sprout is an extensible, privacy-first mobile application platform for turning personal needs into robust local tools. By combining a high-performance **Rust-backed logic engine** with a fluid **Flutter Material 3 interface**, Sprout allows users to build, share, and install multi-screen applications directly on their devices.

## Core Capabilities

| Feature | Description |
| :--- | :--- |
| **Logic Power** | Advanced SproutScript support for `if/else` logic, `for-in` loops, and structured `data` models. |
| **Native Lens** | Real-time photo capture via CameraX and high-speed QR/barcode scanning via Google ML Kit. |
| **Sprout Connect** | Secure, P2P data synchronization for collaborative apps without a central server. |
| **Encrypted Cloud** | Zero-knowledge, passphrase-protected local backups (`.sproutcloud`) for total data ownership. |
| **Visual Builder** | A no-code layer over the source code, including a **Theme Studio** for instant visual customization. |
| **Portable Sharing** | Share complete apps via `.sproutapp` bundles or high-density QR codes with full integrity verification. |

## Quick Start for Contributors

### Environment Setup

To build Sprout from source, you will need Flutter 3.24.0, a Java 17 JDK, Rust stable, and the Android NDK (r26d).

```bash
# Install Android Rust targets
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk --locked

# Build the Rust compiler and Flutter application
bash scripts/build_android_native.sh
cd sprout_app_flutter
flutter pub get
flutter build apk --debug
```

### Quality Assurance

We maintain strict quality gates for both the Rust compiler and the Flutter frontend. All pull requests must pass the following checks:

```bash
# Rust Quality Gates
cargo fmt --all --check
cargo test --all-features
cargo audit

# Flutter Quality Gates
flutter analyze --no-fatal-infos
flutter test test
```

## Documentation & Architecture

For a deep dive into the system design and implementation details, please refer to the following resources:

- **[Implementation Summary](IMPLEMENTATION_SUMMARY.md)**: A detailed report on the Phase 2 architectural overhaul and security hardening.
- **[Product Roadmap](ROADMAP.md)**: Our vision for the future, from custom themes to cross-platform support.
- **[Language Specification](docs/language_spec.md)**: The formal grammar and primitives of SproutScript.
- **[Sync Protocol](docs/sync_protocol.md)**: Technical details of the Sprout Connect P2P synchronization.

## Security Model

Sprout operates on a **zero-trust, local-first** principle. Source code is validated by the Rust compiler before execution, and all user data is stored in encrypted atomic JSON snapshots. We do not transmit project content or personal data to any external servers without explicit, per-action user consent.

---
*Sprout is an open-source project dedicated to empowering users through local-first computing.*
