# Sprout Product Roadmap

Sprout helps people turn small, personal needs into useful tools from their phone. This roadmap keeps the project focused on understandable, local-first creation while making clear which capabilities are available today and which are planned.

## Current foundation

The Android application supports local project creation, AI-generated SproutScript starters, source editing, Rust-backed validation and compilation, and a document-faithful preview of supported labels and buttons. New users can begin with a ranked todo list, counter, notes, or habit-check-in template. The **Learn Sprout** section explains the workflow from idea to preview in five short steps.

| Capability | Current state |
| --- | --- |
| Personal tools | Available through templates and the AI starter flow. |
| AI app starter | Available for ranked todos, counters, navigation, and a safe general starter. Users can inspect, accept, and save the generated source. |
| Local compilation | Available on Android through the packaged Rust compiler libraries. |
| Preview | Available for the compiler’s currently supported static labels and buttons. Preview explicitly reports compile failures instead of showing a misleading sample app. |
| Learning | Available through onboarding lessons and the Learn Sprout home-screen route. |

## Near-term upgrades

The most valuable next step is to align runtime behavior with the language users can see in preview. The compiler already validates a small, safe UI surface; the runtime should next add explicit, testable support for button actions, simple state changes, and navigation. Form inputs, ordered list data, and persistent task completion should follow only after that surface is fully specified and tested.

The project should also add device-level integration tests that create a project, apply an AI starter, reopen the source, compile it, and preview it on arm64 Android hardware. This protects the complete path that users rely on, including Rust native-library packaging.

## Longer-term direction

The repository’s original product notes describe a progression from personal tools to shared apps, a personal “Sprout Garden”, desktop and web authoring, synchronization, voice-assisted creation, and eventually a user-made-app ecosystem. These remain directional ideas rather than release commitments.

| Direction | Suggested readiness milestone |
| --- | --- |
| Shared apps | Export/import and QR transfer with a reviewed project-bundle format and user-visible permission summary. |
| Sprout Garden | Reliable project metadata, search, tags, and project thumbnails. |
| Desktop and web authoring | A shared parser and project format with parity tests before adding synchronization. |
| Voice-assisted creation | On-device or privacy-reviewed speech handling and the same inspect-before-use AI acceptance model. |
| Broader runtime | A documented language specification, deterministic execution semantics, and a security review for every new capability. |

## Product principles

Sprout should remain approachable, privacy-respecting, and explicit about what a generated app will do. Every new feature should preserve a clear path from a user’s request, to visible source, to validation, to a preview that matches that source.
