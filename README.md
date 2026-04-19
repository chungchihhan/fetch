# Fetch
**Fast, keyboard-driven code snippet manager for your Mac.**
Fetch lives in your menu bar (or Dock, or both) and lets you store, browse, and copy code snippets instantly — without leaving your keyboard.


https://github.com/user-attachments/assets/181aa989-2b03-45bd-a480-ef7036992103





<p align="center">
  <img src="https://github.com/user-attachments/assets/68db94e1-d90a-4f7e-9b6b-7168d1687122" width="180" alt="Foxfire" />
  <img src="https://github.com/user-attachments/assets/1de30fa8-b231-4585-9c98-03fc64e05fab" width="180" alt="Gloaming" />
  <img src="https://github.com/user-attachments/assets/1dea227d-0118-4ec0-b4ea-bb8ba143cff5" width="180" alt="Smoulder" />
</p>

<p align="center"><sub><b>Foxfire</b> · <b>Gloaming</b> · <b>Smoulder</b></sub></p>

## Features

- **6 tabs** — organize snippets by language or project
- **Menu bar popover, main window, or both** — pick your workflow in Settings
- **Drag-to-reorder** — grab the grip on the left, or ⌥↑ / ⌥↓ from the keyboard
- **Undo / redo** — ⌘Z / ⌘⇧Z for add, delete, reorder, and content edits
- **Syntax highlighting** — automatic code highlighting via Highlightr
- **Global shortcut** — summon Fetch from anywhere (default: ⌘⌥F, customizable)
- **Icon themes** — Foxfire (green), Gloaming (blue), Smoulder (red) with matching accent colors
- **Frosted-glass translucency** — the popover and window blend with what's behind them
- **Zoom text** — ⌘= / ⌘- adjusts tab, title, and code font sizes in sync
- **Code wrap** — toggle line wrapping for long snippets
- **Resizable** — drag any edge to adjust the window or popover
- **Custom data folder** — store your snippets wherever you want
- **Auto-update** — built-in update checker

## Installation

One-line install:

```bash
curl -fsSL https://github.com/chungchihhan/fetch/releases/latest/download/Fetch.zip -o /tmp/Fetch.zip && unzip -oq /tmp/Fetch.zip -d /Applications && xattr -cr /Applications/Fetch.app && open /Applications/Fetch.app
```

Then go to **System Settings → Privacy & Security → Accessibility**, click **+**, and add Fetch (required for the global shortcut).

Prefer to do it manually? Download **Fetch.zip** from the [latest release](https://github.com/chungchihhan/fetch/releases/latest), unzip, drag to `/Applications`, and right-click → **Open** the first time.

## Display Modes

Choose in **Settings → General → Display Mode**:
- **Both** — menu bar icon + Dock icon; popover and main window stay in sync
- **Menu Bar Only** — classic menu bar popover, no Dock presence
- **Window Only** — no menu bar icon; the main window is the app

## Keyboard Shortcuts

### Global
| Shortcut | Action |
|----------|--------|
| ⌘⌥F      | Toggle Fetch (customizable in Settings) |

### Browse
| Shortcut   | Action |
|------------|--------|
| ⌘1 – ⌘6    | Switch tabs |
| ↑ / ↓      | Navigate snippets |
| ↵          | Copy code only |
| ⌘C         | Copy title with code |
| ⌘E         | Enter edit mode |
| ⌘N         | New snippet |
| ⌘D         | Delete focused snippet |
| ⌥↑ / ⌥↓    | Reorder snippet up / down |
| ⌘Z / ⌘⇧Z   | Undo / Redo |
| ⌘= / ⌘-    | Increase / decrease text size |
| ⌘,         | Open Settings |
| Esc        | Close popover |

### Edit
| Shortcut     | Action |
|--------------|--------|
| Tab / ⇧Tab   | Switch between title and code |
| ↵            | Save and exit |
| Esc          | Save and exit |
| ⇧↵           | Newline in code |
| ⌘E           | Exit edit |

## License

MIT © 2026 Chih-Han Chung
