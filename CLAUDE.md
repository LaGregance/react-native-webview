# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Community-maintained `react-native-webview` package — a cross-platform WebView component for React Native. Ships TypeScript JS bindings plus native implementations for iOS, Android, macOS, and Windows. Supports both the old (Paper) and new (Fabric) React Native architectures.

The package is consumed via `index.js` (compiled `lib/`) for end-users and `src/index.ts` for internal/Metro use (`react-native` field in `package.json`).

## Tooling

- Package manager: **Bun** (`bun.lock`, frozen in CI). Don't use `yarn` or `npm` — older docs reference yarn but the active toolchain is Bun.
- TypeScript: uses **`tsgo`** (`@typescript/native-preview`) instead of stock `tsc` — invoked via `bun run lint:tsgo`.
- Linter / formatter: **oxlint** + **oxfmt** (not ESLint/Prettier, despite leftover `@react-native/eslint-config` in devDeps).
- Build: Babel transpiles `src/*.{ts,tsx}` → `lib/`; `tsgo` emits `.d.ts` declarations into `lib/`.
- Releases: `semantic-release` driven by Conventional Commits, triggered on push to `master`.

## Common commands

```sh
bun install --frozen-lockfile     # install deps (CI uses --frozen-lockfile)
bun run lint                      # tsgo + oxlint + oxfmt (run before pushing)
bun run lint:tsgo                 # type-check only
bun run lint:oxlint               # lint only
bun run lint:oxfmt                # format check / apply
bun run prepare                   # full build: emit .d.ts then babel-compile to lib/

bun run android                   # run example app on Android
bun run ios                       # run example app on iOS (requires `pod install --project-directory=example/ios` first)
bun run macos                     # run example app on macOS (requires `pod install --project-directory=example/macos` first)
bun run windows                   # run example app on Windows
bun run start                     # Metro bundler

bun run jest                      # JS unit tests (jest preset: react-native; see __tests__ and src/__tests__)
bun run jest path/to/file.test    # single test file
bun run test:windows              # Appium-based Windows e2e (requires the windows-ci workflow's setup)
```

iOS new-architecture toggle: `RCT_NEW_ARCH_ENABLED=1 pod install --project-directory=example/ios`.
Android new-architecture toggle: pass `-PnewArchEnabled=true` to gradle.

## Architecture

### Per-platform JS entry points

`src/WebView.<platform>.tsx` is selected by Metro/Babel based on the runtime platform:

- `WebView.ios.tsx`, `WebView.android.tsx`, `WebView.macos.tsx`, `WebView.windows.tsx` — each is a `forwardRef` component that wires platform-specific props to the native component.
- `WebView.tsx` (no extension) is the **fallback** for unsupported platforms (e.g. Expo web) — it just renders a "not supported" message.
- `WebView.styles.ts` — shared styles.
- `WebViewShared.tsx` — shared logic (origin whitelist, default loading/error renderers, `useWebViewLogic` hook used by all platform implementations).
- `WebViewTypes.ts` — the canonical prop/event types for all platforms; `WebViewProps` is the intersection `IOSWebViewProps & AndroidWebViewProps & WindowsWebViewProps`.

### Codegen (Fabric / new arch)

- `src/RNCWebViewNativeComponent.ts` — codegen spec for the native component (`RNCWebView`). The `codegenConfig` block in `package.json` (name `RNCWebViewSpec`) tells RN's codegen to scan `./src` for codegen specs.
- `src/NativeRNCWebViewModule.ts` — TurboModule spec for imperative commands (e.g. `clearCache`, `injectJavaScript` plumbing on some platforms).
- `src/WebViewNativeComponent.macos.ts`, `src/WebViewNativeComponent.windows.ts` — platform-specific codegen specs.

When changing a prop or event in `src/RNCWebViewNativeComponent.ts`, the corresponding native code must implement it on every platform that supports it. The codegen output drives the bridge interface in both arches.

### Native source trees

- `apple/` — iOS + tvOS + visionOS shared Objective-C / Objective-C++ implementation. Key files: `RNCWebView.mm` (Fabric component), `RNCWebViewImpl.m` (the actual UIView/`WKWebView` host), `RNCWebViewManager.mm` (Paper view manager), `RNCWebViewModule.mm` (TurboModule), `RNCWebViewDecisionManager.m` (navigation decision plumbing for `onShouldStartLoadWithRequest`), `RNCWKProcessPoolManager.m` (shared `WKProcessPool`).
- `ios/RNCWebView.xcodeproj`, `macos/RNCWebView.xcodeproj` — Xcode projects that wrap `apple/` for each Apple platform.
- `android/src/main/java/com/reactnativecommunity/webview/` — shared Android (Java + Kotlin) implementation: `RNCWebView`, `RNCWebViewClient`, `RNCWebChromeClient`, `RNCWebViewManagerImpl`, `RNCWebViewModuleImpl`, `RNCWebViewMessagingModule`, `RNCWebViewWrapper`, plus `events/Top*Event.kt` event classes.
- `android/src/newarch/` and `android/src/oldarch/` — architecture-specific `RNCWebViewManager` and `RNCWebViewModule` shims; gradle picks the right source set based on `newArchEnabled`.
- `windows/ReactNativeWebView/` — C++/WinRT implementation (`ReactWebView*`, `ReactWebView2*` for the WebView2 backend, `WebBridge.cpp`).

### Example app

`example/` is a `react-native-test-app` host shared across all four platforms. It's wired up in `react-native.config.js`. `example/App.tsx` registers a switcher of demos under `example/examples/` (`Messaging`, `Alerts`, `Downloads`, `Uploads`, `Injection`, `OpenWindow`, `SslError`, …). Some demos have a `.windows.tsx` variant.

This example app is what CI builds for `android-ci.yml`, `ios-ci.yml`, `macos-ci.yml`, `windows-ci.yml`. Use it for manual verification of native changes.

## Conventions

- **Commits drive releases.** semantic-release reads commit messages — use Conventional Commits (`fix:`, `feat:`, `chore:`, `feat!:` for breaking). Land on `master` triggers a publish.
- **Don't edit `lib/`.** It's generated by `bun run prepare`. Always edit `src/`.
- **Cross-platform parity matters.** A prop change in `src/RNCWebViewNativeComponent.ts` or `WebViewTypes.ts` is a contract — at minimum extend the relevant `WebView.<platform>.tsx` and the platform's native code on every platform that supports it. If a prop is genuinely platform-specific, gate it in the typed prop union (`IOSWebViewProps`, `AndroidWebViewProps`, `WindowsWebViewProps`) and document it in `docs/Reference.md`.
- **Both architectures must keep working.** Old arch (Paper) and new arch (Fabric) are both shipped — Android has split source sets for this; iOS uses runtime branches in `apple/`. Test new-arch builds when touching native bridging.
- **Public API docs live in `docs/`.** `docs/Reference.md` (props/methods), `docs/Guide.md` (recipes), `docs/Getting-Started.md`. Translations exist (`*.italian.md`, `*.portuguese.md`, etc.) — only update English unless asked.
- **Lint is the gate.** PRs run `bun run lint:ci` only — no JS unit-test job in CI for the library itself (the platform CI jobs build the example app instead). Make sure `bun run lint` is clean.
