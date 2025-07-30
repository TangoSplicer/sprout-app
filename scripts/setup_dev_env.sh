#!/bin/bash
# scripts/setup_dev_env.sh

echo "Setting up Sprout development environment..."

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Install dependencies
flutter pub get
dart pub global activate flutter_rust_bridge

echo "✅ Sprout dev environment ready!"