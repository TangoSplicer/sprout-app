# Sprout Architecture

## System Layers

1. **Flutter Frontend (Material 3)**: Provides the dashboard, project management, visual component builder, syntax editor, interactive preview runtime, version history, app gallery, and sharing interfaces.
2. **Rust Compiler (`sprout_compiler`)**: Parses SproutScript source into a robust AST, validates safety constraints, compiles native dynamic libraries (`libsprout_compiler.so`), and executes runtime action dispatch.
3. **Android Native Bridge (`MainActivity.kt` & `NativeBridge`)**: Handles secure content sharing, incoming `.sproutapp` imports, native local notifications, and Android home-screen shortcut proxy launching.
4. **Durable Local Storage (`ProjectService`)**: Manages per-project files (`main.sprout`, `app_state.json`) with atomic replacement, serialized autosave snapshots, and version history checkpoints.

## Data Flow

```text
User Action / Visual Builder / AI Starter
       ↓
SproutScript Source (`main.sprout`)
       ↓
Rust Compiler / AST Validation (`sprout_compiler`)
       ↓
Interactive Preview Runtime / State Persistence (`app_state.json`)
       ↓
Native Android Shortcuts & Portable Package Sharing (`.sproutapp`)
```
