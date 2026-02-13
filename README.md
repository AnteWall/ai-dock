# ai-dock

![macOS](https://img.shields.io/badge/platform-macOS-black)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Type](https://img.shields.io/badge/type-menu--bar%20app-2ea44f)

`ai-dock` is a macOS menu bar companion that tracks active AI coding sessions and surfaces when they are running, finished, or waiting for input. It supports both Claude Code hook events and OpenCode plugin events. The UI is notch-aware and keeps live status visible without switching terminal windows.

## Preview

<p align="center">
  <img src="docs/dock-open.png" alt="ai-dock open" width="420" />
  <img src="docs/dock-closed.png" alt="ai-dock closed" width="420" />
</p>

## Install

### From GitHub release
1. Open the [latest release](releases/latest).
2. Download the latest `ai-dock-<version>.dmg` asset from that page.
3. Open the DMG and move `ai-dock.app` to `/Applications`.
4. Open the app once and keep it running in the menu bar.

### If macOS blocks launch
1. Move `ai-dock.app` to `/Applications` and try opening once.
2. Open **System Settings -> Privacy & Security** and click **Open Anyway** for `ai-dock`.
3. If that option does not appear (or only **Move to Bin** is shown), run this fallback:

```bash
xattr -dr com.apple.quarantine /Applications/ai-dock.app
codesign --force --deep --sign - /Applications/ai-dock.app
open /Applications/ai-dock.app
```

### OpenCode integration
- If `~/.config/opencode/` exists, `ai-dock` auto-installs its plugin.
- Verify in app: **Settings -> OpenCode Plugin**.

### Claude Code integration
- Install Claude hooks from app: **Settings -> Claude Code Hooks -> Install Hooks**.

## Development

### Build locally
```bash
xcodebuild -project "ai-dock.xcodeproj" -scheme "ai-dock" -configuration Debug -destination 'platform=macOS' build
```

### Run from Xcode
1. Open `ai-dock.xcodeproj`.
2. Select scheme `ai-dock`.
3. Run on **My Mac**.

### Local signing override (optional)
```bash
cp Config/Signing.local.example.xcconfig Config/Signing.local.xcconfig
```

Set your Apple team and bundle id in `Config/Signing.local.xcconfig`.

### CI and release
- CI workflow: `.github/workflows/ci.yml`
- Release workflow: `.github/workflows/release.yml`
- Publish a release by pushing a tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```
