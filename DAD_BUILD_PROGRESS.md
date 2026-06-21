# VisionClaw Dad Build — Progress & Adaptation Notes

This repo is a personalized build of VisionClaw following `visionclaw-dad-build.md`.
It adds Features A–K from the guide. Because the guide's code snippets are
idealized, the actual integration was adapted to the real codebase. This file
records what changed and what still must be done by hand.

## Architecture adaptations (vs. the guide)

- **Tool declarations.** The guide shows `FunctionDeclaration(...)`/`Schema(...)`
  Swift types. The real app declares tools as plain `[String: Any]` dictionaries
  in `OpenClaw/ToolCallModels.swift` → `ToolDeclarations.allDeclarations()`.
  All new tools were added there in that style.
- **Tool routing.** The real `OpenClaw/ToolCallRouter.swift` has no `switch` — it
  forwards every call to OpenClaw. A local-tool dispatch hook was added: if a
  call name is a known local tool it is handled in `Services/LocalTools.swift`,
  otherwise it falls through to OpenClaw's `execute` (unchanged behavior).
- **System prompt.** Lives in `Gemini/GeminiConfig.swift` as
  `defaultSystemInstruction`. Feature guidance was appended there.
- **Sending iMessages from local tools.** The guide calls a non-existent
  `OpenClawBridge.shared.execute(...)`. Real calls go through the injected
  `bridge.delegateTask(task:toolName:)` (toolName `execute`).
- **Latest camera frame** (parking photo). The guide references
  `CameraManager.shared.latestFrame`. The real app exposes frames via
  `GeminiSessionViewModel.sendVideoFrameIfThrottled`; a tiny
  `Services/LatestFrameStore.swift` singleton caches the most recent frame.
- **Google services** are wrapped in `#if canImport(GoogleSignIn)` so the project
  still builds before the Google Sign-In package is added, then activates after.

## Manual steps the guide requires (cannot be automated here)

See `DAD_MANUAL_STEPS.md` for the full checklist. In short: install the Google
Sign-In Swift package, set up the Google Cloud OAuth client, add the Gemini API
key in `Secrets.swift`, set up OpenClaw, create the iOS Shortcuts (FocusOn/FocusOff),
and build/run on the iPhone from Xcode.
