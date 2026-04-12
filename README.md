# Fetch

**Fast, keyboard-driven code snippet manager for your Mac menu bar.**

Fetch lives in your menu bar and lets you store, browse, and copy code snippets instantly — without leaving your keyboard.

---

## Features

- **6 tabs** — organize snippets by language or project
- **Syntax highlighting** — automatic code highlighting via Highlightr
- **Keyboard-first** — navigate, edit, and copy without touching the mouse
- **Global shortcut** — summon Fetch from anywhere with a customizable hotkey (default: ⌘⌥J)
- **Code wrap** — toggle line wrapping for long snippets
- **Resizable** — drag to adjust the width and height of the popover
- **Appearance** — system, light, or dark mode
- **Custom data folder** — store your snippets wherever you want
- **Customizable font sizes** — separate controls for title and code

---

## Installation

1. Download **Fetch.zip** from the [latest release](https://github.com/chungchihhan/fetch/releases/latest)
2. Unzip and drag **Fetch.app** to your `/Applications` folder
3. Right-click → **Open** → **Open** (required once since the app is unsigned)
4. Go to **System Settings → Privacy & Security → Accessibility**, click **+** and add Fetch (needed for the global shortcut)

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⌥F | Toggle Fetch (customizable in Settings) |
| ⌘1 – ⌘6 | Switch tabs |
| ↑ / ↓ | Navigate snippets |
| Enter | Copy focused snippet |
| ⌘E | Enter edit mode |
| Tab | Switch between title and code while editing |
| Esc | Cancel edit |
| ⌘N | New snippet |
| ⌘C | Copy focused snippet |
| ⌘D | Delete focused snippet |
| ⌘, | Open Settings |

---

## Building from Source

**Requirements:** macOS 14.0+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/chungchihhan/fetch.git
cd fetch
xcodegen generate
open Fetch.xcodeproj
```

Then build and run with ⌘R in Xcode.

---

## License

MIT © 2026 Chih-Han Chung
