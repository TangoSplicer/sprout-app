# Sprout Roadmap

## 🚀 Phase 1: Core Platform & Infrastructure (Completed)
- **Rust Compiler (`sprout_compiler`)**: Extended AST, parser, and runtime with `If`, `Loop`, `SyncData`, `NotifyUser`, `Fetch`, `Scan`, and `Camera` primitives.
- **Flutter Frontend**: Implemented Visual Component Builder, Local Version History (20 snapshots), and In-App App Gallery.
- **Portable Packages**: Created `.sproutapp` format for per-app sharing with integrity verification.
- **Android Integration**: Home-screen proxy shortcuts, native notifications, and secure sharing.
- **Sprout Connect**: P2P data synchronization for collaborative apps.
- **Media & Insights**: Integrated charts, audio player, and safe web fetch actions.

## 🔒 Phase 2: Logic Power, Cloud & Lens (Completed)
- **Advanced Logic**: Full support for `if/else` and `for-in` loops in SproutScript.
- **Data Models**: Structured schema support with the `data` keyword for robust state management.
- **Real Lens**: Native Android CameraX integration for photo capture and Google ML Kit for QR/barcode scanning.
- **Encrypted Backups**: Zero-knowledge PBKDF2 + AES-256-GCM encrypted local backups (`.sproutcloud`).
- **Security Hardening**: Remediated 12 Dependabot vulnerabilities and implemented strict sandbox execution.
- **UI Polish**: Eliminated mobile overflows, redesigned terminal header, and added dynamic Theme Studio.

## 🎨 Phase 3: Theme Studio & Enhanced UX (In Progress)
- [x] **Theme Studio**: Visual preset picker (Forest, Ocean, Sunset, Minimal).
- [ ] **Custom Themes**: Allow users to define their own color palettes and typography in the Visual Builder.
- [ ] **Advanced Templates**: Build out the "Budget Planner" and "Inventory Tracker" templates using Data Models.
- [ ] **Guided Tour**: Update the "Learn Sprout" tour to cover collaborative and media patterns.

## 🌐 Phase 4: Full Cloud Sync & Ecosystem (Future)
- [ ] **Sprout Web**: Run Sprout apps directly in the browser via Wasm.
- [ ] **Cross-Device Sync**: Optional encrypted cloud sync between multiple user devices.
- [ ] **Community Gallery**: A public hub for sharing verified `.sproutapp` packages.
- [ ] **Sprout Desktop**: Native versions for Windows, macOS, and Linux.
