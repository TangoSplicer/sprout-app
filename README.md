# 🌱 Sprout

**Grow apps that grow with you.**

Sprout is a mobile app that lets anyone create, run, and install custom tools — right from their phone. No experience needed.

Write code in **SproutScript**: simple, elegant, and powerful.  
Then tap **Run** — and use your app like any other.

> “Not everyone should code. But everyone should create.”

---

## 🚀 Features

- ✍️ Write apps in **SproutScript** — a language designed for humans
- 🔁 Instant preview — see changes as you type
- 📲 Compile & install locally — no cloud, no app store
- 🤖 AI Assistant — describe your idea, get code
- 🌐 Share & remix — grow a garden of personal tools

## 📱 Platforms

- iOS (iPhone)
- Android

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Language**: Rust + Custom Compiler
- **Runtime**: WASM (Wasm3)
- **Bridge**: `flutter_rust_bridge`

## 💡 Getting Started

```bash
git clone https://github.com/TangoSplicer/sprout-app.git
cd sprout-app

# Install Flutter dependencies
flutter pub get

# Build Rust bridge
dart run flutter_rust_bridge:build

# Run on device
flutter run
```

### Development Requirements

- **Flutter**: 3.10.0 or higher
- **Rust**: 1.70.0 or higher
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)
- **VS Code** (recommended): With Flutter and Rust extensions

### Project Structure

- `/flutter`: Flutter mobile app
- `/rust`: Rust compiler and runtime
- `/bridge`: Flutter-Rust bridge
- `/web-dashboard`: Web dashboard for app management
- `/docs`: Documentation and specifications
