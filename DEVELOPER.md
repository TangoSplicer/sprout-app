# Sprout Developer Guide

This guide provides detailed instructions for setting up and contributing to the Sprout app development.

## 🛠️ Development Environment Setup

### Prerequisites

- **Flutter**: Version 3.10.0 or higher
  - [Flutter Installation Guide](https://flutter.dev/docs/get-started/install)
- **Rust**: Version 1.70.0 or higher
  - [Rust Installation Guide](https://www.rust-lang.org/tools/install)
- **Android Studio**: For Android development
  - [Android Studio Installation](https://developer.android.com/studio)
- **Xcode**: For iOS development (macOS only)
  - Available on the Mac App Store
- **VS Code** (recommended): With Flutter and Rust extensions
  - [VS Code Installation](https://code.visualstudio.com/)
  - Extensions: Flutter, Rust-analyzer, Dart

### Setting Up the Project

1. **Clone the repository**:
   ```bash
   git clone https://github.com/TangoSplicer/sprout-app.git
   cd sprout-app
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Build the Rust bridge**:
   ```bash
   dart run flutter_rust_bridge:build
   ```

4. **Run the app**:
   ```bash
   flutter run
   ```

## 📁 Project Structure

- `/flutter`: Flutter mobile app
  - `/lib`: Dart code for the app
    - `/models`: Data models
    - `/screens`: UI screens
    - `/services`: Business logic and services
    - `/widgets`: Reusable UI components
    - `/utils`: Utility functions
  - `/assets`: Static assets like images and fonts

- `/rust`: Rust compiler and runtime
  - `/sprout_compiler`: The SproutScript compiler
    - `/src`: Source code
      - `ast.rs`: Abstract Syntax Tree definitions
      - `parser.rs`: Parser implementation
      - `generator.rs`: Code generator
      - `runtime.rs`: Runtime implementation
      - `lib.rs`: Library entry point

- `/bridge`: Flutter-Rust bridge
  - `bridge.dart`: Bridge implementation

- `/web-dashboard`: Web dashboard for app management
  - `/src`: React components and logic
  - `/public`: Static assets

- `/docs`: Documentation and specifications
  - `architecture.md`: System architecture
  - `language_spec.md`: SproutScript language specification
  - `packages.md`: Package management documentation
  - `sync_protocol.md`: Synchronization protocol

## 🧪 Testing

### Running Tests

- **Flutter tests**:
  ```bash
  flutter test
  ```

- **Rust tests**:
  ```bash
  cd rust/sprout_compiler
  cargo test
  ```

### Adding Tests

- **Flutter**: Add tests in the `/flutter/test` directory
- **Rust**: Add tests in the `/rust/sprout_compiler/tests` directory

## 🔄 Development Workflow

1. **Create a new branch** for your feature or bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and commit them:
   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

3. **Push your branch** to GitHub:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create a pull request** on GitHub

## 📝 Coding Standards

### Flutter/Dart

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter format` to format your code
- Run `flutter analyze` to check for issues

### Rust

- Follow the [Rust Style Guide](https://doc.rust-lang.org/1.0.0/style/README.html)
- Use `cargo fmt` to format your code
- Run `cargo clippy` to check for issues

## 🔍 Debugging

### Flutter App

- Use VS Code's Flutter debugging tools
- Enable hot reload for faster development
- Check logs in the debug console

### Rust Code

- Use `println!` for simple debugging
- For more complex cases, use the Rust debugger in VS Code

## 📚 Documentation

- Document all public APIs
- Update relevant documentation when making changes
- Add comments for complex logic

## 🤝 Contributing

1. Check the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines
2. Look for issues labeled "good first issue" to get started
3. Discuss major changes in an issue before implementing

## 🔒 Security

- Follow security best practices
- Never commit sensitive information
- Report security vulnerabilities according to [SECURITY.md](SECURITY.md)

## 📱 Building for Production

### Android

```bash
flutter build apk --release
```

### iOS (macOS only)

```bash
flutter build ios --release
```

### Web Dashboard

```bash
cd web-dashboard
npm run build
```

## 🌐 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Rust Documentation](https://doc.rust-lang.org/)
- [WebAssembly Documentation](https://webassembly.org/docs/high-level-goals/)
- [Flutter Rust Bridge Documentation](https://github.com/fzyzcjy/flutter_rust_bridge)