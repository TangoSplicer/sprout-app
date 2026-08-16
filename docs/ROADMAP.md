# Sprout Platform Roadmap & Capabilities

Sprout helps people turn small, personal needs into useful tools from their phone. This roadmap documents the core platform capabilities available today.

## Current Production Foundation

Sprout is a fully realized local-first application platform featuring a Rust compiler backend (SproutScript) and a warm Material 3 Flutter frontend for Android and cross-platform devices.

| Capability | Current State |
| --- | --- |
| **Language & Compiler** | Bounded SproutScript grammar with strict security validation, Clippy checks, and full unit test coverage. |
| **Visual Builder** | No-code drag-and-drop component builder that generates clean, valid SproutScript source in the background. |
| **Version History** | Automated point-in-time project snapshots and manual time-travel restore points in the editor. |
| **App Gallery** | In-app marketplace for discovering, previewing, and instantly adopting curated community patterns. |
| **Portable Packages** | Secure `.sproutapp` archives for offline per-app sharing, integrity verification, and non-destructive imports. |
| **Home-Screen Proxies** | Native Android shortcuts that launch named Sprout apps directly into their interactive runtime. |
| **Sprout Connect (P2P Sync)** | Local-network data synchronization for collaborative apps with explicit user consent. |
| **Media & Insights** | Native charts (`bar`, `line`, `pie`), audio players, and safe web `fetch` actions with domain confirmation. |
| **Interactive Preview** | Real-time runtime supporting state, inputs, choices, searchable editable records, breakdowns, and aggregates. |

## Product Principles

Sprout remains approachable, privacy-respecting, and explicit about what a generated app will do. Every feature preserves a clear path from a user's request, to visible source, to validation, to an interactive preview that matches that source.
