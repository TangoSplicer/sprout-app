
---

### 📄 `docs/architecture.md`
```markdown
# Sprout Architecture

## Layers
1. **Flutter UI** – Editor, preview
2. **Rust Compiler** – Parses SproutScript
3. **WASM Runtime** – Executes logic
4. **Export Engine** – Generates APK/IPA

## Data Flow
Editor → Rust (AST) → WASM → Preview  
       ↓  
   Export → APK/IPA