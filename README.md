# Sprout

**Grow apps that grow with you.**

Sprout is an Android-focused mobile app for turning a small personal need into a simple local tool. A user can begin from a template or an AI-generated SproutScript starter, review the resulting source, save it to a project, compile it locally with the Rust compiler, and preview the supported interface.

> Sprout is designed to start with an idea rather than a framework. The user remains in control of the generated source and every saved change.

## What works today

| Capability | Description |
| --- | --- |
| Guided starts | Ranked Todo, Counter, Quick Notes, and Habit Check-in templates are available from **New App**. |
| AI starters | Ask for a todo list, counter, navigation app, or a general starter. **Use** replaces and saves the current project source. |
| Local compilation | The Rust compiler is built into Android APKs for arm64-v8a, armeabi-v7a, and x86_64. |
| Faithful preview | The preview renders the app name, first screen, labels, and buttons declared in the current SproutScript document. It reports compilation failures instead of opening a canned sample. |
| Learning | The in-app **Learn Sprout** route and onboarding explain the idea → source → preview workflow without assuming coding experience. |

## Quick start for contributors

### Prerequisites

Install Flutter 3.24.0, a Java 17 JDK, Rust stable, Android NDK r26d, and `cargo-ndk`. Install the Android Rust targets once:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk --locked
```

Set `ANDROID_NDK_HOME` (or `ANDROID_NDK_ROOT`) to the installed NDK directory. The Android Gradle `preBuild` task runs `scripts/build_android_native.sh` automatically, so an APK build packages the Rust compiler libraries before it assembles.

```bash
export PATH="/path/to/flutter/bin:$PATH"
export JAVA_HOME=/path/to/java-17
export ANDROID_SDK_ROOT=/path/to/android-sdk
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/26.3.11579264"

cd sprout_app_flutter
flutter pub get
flutter analyze --no-fatal-infos
flutter test test
flutter build apk --debug
```

The test APK is written to `sprout_app_flutter/build/app/outputs/flutter-apk/app-debug.apk`.

## Quality checks

Run the Rust and Flutter checks before opening a pull request:

```bash
source "$HOME/.cargo/env"
cargo fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features

cd sprout_app_flutter
flutter analyze --no-fatal-infos
flutter test test
```

## Project direction

Sprout is currently focused on reliable personal tools and an understandable local-first workflow. Its longer-term direction includes shareable project bundles, a personal app garden, desktop/web authoring, and voice-assisted creation. See [the roadmap](docs/ROADMAP.md) for current scope, proposed milestones, and product principles.

## Repository layout

| Path | Purpose |
| --- | --- |
| `rust/sprout_compiler` | Rust parser, compiler, validation surface, and mobile C ABI. |
| `sprout_app_flutter` | Flutter Android application, app routes, templates, learning flow, and tests. |
| `scripts/build_android_native.sh` | Cross-compiles and copies the Rust shared libraries into Android JNI resources. |
| `docs/ROADMAP.md` | Product scope, future directions, and readiness milestones. |

## Security model

Sprout validates source before compilation and uses a local compiler bridge. Generated projects are explicit source files, not opaque executables. Do not add capabilities that execute arbitrary code, request a permission, or transmit project content without an explicit user-facing design and review.
