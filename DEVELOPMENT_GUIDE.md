# Sprout Development Guide

## 🛠️ Setting Up the Development Environment

### Prerequisites

To develop Sprout, you'll need:

1. **Rust** (for the compiler)
   - Install from: https://rustup.rs/
   - Verify: `rustc --version` and `cargo --version`

2. **Flutter** (for the mobile app)
   - Install from: https://flutter.dev/docs/get-started/install
   - Verify: `flutter --version`

3. **Android Studio / Xcode** (for mobile deployment)
   - Android: Android Studio with SDK
   - iOS: Xcode (macOS only)

4. **Git** (for version control)
   - Verify: `git --version`

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/TangoSplicer/sprout-app.git
cd sprout-app

# Install Flutter dependencies
cd flutter
flutter pub get

# Install Node.js dependencies (for web dashboard)
cd ../web-dashboard
npm install

# Return to root
cd ..
```

---

## 📁 Project Structure

```
sprout-app/
├── flutter/                  # Flutter mobile application
│   ├── lib/                 # Dart source code
│   │   ├── main.dart       # Entry point
│   │   ├── editor/         # Code editor components
│   │   ├── preview/        # Live preview components
│   │   └── compiler/       # Compiler bridge
│   ├── assets/             # Images, fonts, etc.
│   └── pubspec.yaml        # Flutter dependencies
│
├── rust/                    # Rust compiler
│   └── sprout_compiler/
│       ├── src/
│       │   ├── lib.rs      # Library entry point
│       │   ├── ast.rs      # Abstract Syntax Tree
│       │   ├── parser.rs   # SproutScript parser
│       │   ├── generator.rs # WASM/Android generator
│       │   └── runtime.rs  # Runtime execution
│       └── tests/          # Test suites
│
├── android/                 # Android native code
│   └── app/                # Android-specific configuration
│
├── web-dashboard/           # Web dashboard
│   ├── src/                # TypeScript/JavaScript source
│   ├── index.html          # Entry HTML
│   └── package.json        # Node dependencies
│
├── scripts/                 # Build & deployment scripts
│   ├── build_apk.sh       # APK build automation
│   ├── setup_dev_env.sh   # Environment setup
│   └── sign_apk.sh        # APK signing
│
└── docs/                    # Documentation
    ├── architecture.md     # System architecture
    ├── language_spec.md    # SproutScript reference
    └── sync_protocol.md    # Data sync protocol
```

---

## 🚀 Running the Project

### Flutter App (Mobile)

```bash
cd flutter

# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>

# Build APK
flutter build apk
```

### Rust Compiler

```bash
cd rust/sprout_compiler

# Build the library
cargo build

# Run tests
cargo test

# Build with optimizations
cargo build --release
```

### Web Dashboard

```bash
cd web-dashboard

# Start development server
npm run dev

# Build for production
npm run build
```

---

## 🧪 Testing

### Rust Tests

```bash
cd rust/sprout_compiler

# Run all tests
cargo test

# Run specific test
cargo test test_string_literal_preservation

# Run tests with output
cargo test -- --nocapture
```

### Flutter Tests

```bash
cd flutter

# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

---

## 📝 SproutScript Language Reference

### Basic Structure

```sprout
app "My App" {
    start = Home
}

screen Home {
    state count = 0
    
    ui {
        label "Counter App"
        label "${count}"
        
        button "Increment" {
            count = count + 1
        }
    }
}
```

### Data Models

```sprout
data Task {
    title: String
    done: Boolean = false
    priority: Int = 5
    dueDate: Date
}
```

### Navigation

```sprout
button "Go to Details" {
    -> DetailPage(42, "Example")
}

screen DetailPage(id: Int, name: String) {
    ui {
        label "${id}"
        label name
    }
}
```

### Conditionals

```sprout
if is_logged_in {
    label "Welcome!"
} else {
    label "Please login"
}
```

---

## 🔧 Building for Production

### Android APK

```bash
# Use the build script
./scripts/build_apk.sh

# Or manually
cd flutter
flutter build apk --release

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### iOS (macOS only)

```bash
cd flutter
flutter build ios --release

# Open in Xcode
open ios/Runner.xcworkspace
# Archive and distribute from Xcode
```

---

## 🐛 Debugging

### Flutter App

```bash
# Run with verbose logging
flutter run --verbose

# Debug mode
flutter run --debug

# Profile mode
flutter run --profile
```

### Rust Compiler

```bash
# Enable debug output
RUST_LOG=debug cargo run

# Run with debugger
rust-gdb target/debug/sprout_compiler
```

---

## 📚 Key Concepts

### Compiler Pipeline

1. **Parsing** (`parser.rs`)
   - Tokenizes SproutScript source
   - Builds Abstract Syntax Tree (AST)

2. **Code Generation** (`generator.rs`)
   - Converts AST to WASM
   - Generates Android native code

3. **Runtime** (`runtime.rs`)
   - Executes compiled code
   - Manages state and events

### Flutter Bridge

The `flutter_rust_bridge` connects Flutter UI with Rust compiler:

```rust
#[frb(sync)]
pub fn compile(source: String) -> Vec<u8> {
    // Compile SproutScript to WASM
}
```

---

## 🤝 Contributing

### Code Style

- **Rust**: Follow `rustfmt` conventions
- **Dart**: Follow `dart format` conventions
- **Comments**: Document public APIs

### Commit Messages

```
feat: add conditional UI support
fix: parser error with multiline strings
docs: update language reference
test: add unit tests for AST
```

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a PR

---

## 📖 Additional Resources

- [Architecture Documentation](docs/architecture.md)
- [Language Specification](docs/language_spec.md)
- [Roadmap](ROADMAP.md)
- [FAQ](docs/FAQ.md)

---

**Need help?** Check the [Issues](https://github.com/TangoSplicer/sprout-app/issues) or start a discussion!