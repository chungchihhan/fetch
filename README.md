# Fetch

<p align="center">
  <strong>Fast, keyboard-driven code snippet manager for your Mac.</strong><br/>
  Lives in your menu bar, stays out of your way, and gets snippets into your clipboard instantly.
</p>

<br/>

<details>
  <summary> Watch demo</summary>
  <br/>
  
  https://github.com/user-attachments/assets/181aa989-2b03-45bd-a480-ef7036992103
  
</details>

## Themes

Three visual styles, each with matching accent colors across the entire UI.

<div align="center">

| Foxfire | Gloaming | Smoulder |
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/68db94e1-d90a-4f7e-9b6b-7168d1687122" width="120" /> | <img src="https://github.com/user-attachments/assets/1de30fa8-b231-4585-9c98-03fc64e05fab" width="120" /> | <img src="https://github.com/user-attachments/assets/1dea227d-0118-4ec0-b4ea-bb8ba143cff5" width="120" /> |
| <img src="https://github.com/user-attachments/assets/779d2e9d-97ae-4410-b973-e799981b23bf" width="300" /> | <img src="https://github.com/user-attachments/assets/a74bbc0b-22f9-43fb-8817-16a1072a5949" width="300" /> | <img src="https://github.com/user-attachments/assets/023dc6db-9c35-4aba-bd13-31bc7f8839df" width="300" /> |

</div>


## What it's for

**⌘E to edit — Enter to copy.** Switch between editing and deploying a snippet in milliseconds. The whole interface is designed to keep your hands on the home row.

<p align="center">
  <img src="https://github.com/user-attachments/assets/bd0216df-f996-4c38-8649-a2727507298d" width="48%" />
  <img src="https://github.com/user-attachments/assets/75afa66a-5c1b-46dd-93df-70a0ddd74fc5" width="48%" />
</p>

Stop hunting for that one AI prompt or long terminal command. Fetch keeps them categorized, readable, and one keystroke away.

<p align="center">
  <sub>AI prompts</sub><br/>
  <img src="https://github.com/user-attachments/assets/5a1de62f-53dd-4460-a052-1ba4f89173f9" width="90%" />
</p>

<p align="center">
  <sub>Terminal commands</sub><br/>
  <img src="https://github.com/user-attachments/assets/da9e9134-bf29-4b3d-bedf-4a1868588fac" width="90%" />
</p>

<p align="center">
  <sub>Addresses, IDs, phone numbers — anything you retype too often</sub><br/>
  <img src="https://github.com/user-attachments/assets/e4ee65af-3310-4ab5-99b6-3175136fd133" width="90%" />
</p>


## Features

- **6 tabs** — organize snippets by project, language, or context
- **Menu bar, main window, or both** — configure your preferred workflow in Settings
- **Drag-to-reorder** — grab the grip handle, or use ⌥↑ / ⌥↓ from the keyboard
- **Undo / redo** — ⌘Z / ⌘⇧Z across adds, deletes, reorders, and edits
- **Syntax highlighting** — automatic via Highlightr
- **Global shortcut** — summon Fetch from anywhere (default ⌘⌥F, fully customizable)
- **Three themes** — Foxfire, Gloaming, and Smoulder with matching accent colors
- **Frosted-glass UI** — the popover and window blend naturally with your desktop
- **Zoom text** — ⌘= / ⌘- adjusts tab, title, and code font sizes together
- **Code wrap** — toggle line wrapping per-session
- **Resizable** — drag any edge to fit your screen
- **Custom data folder** — keep your snippets wherever you want
- **Auto-update** — built-in update checker

## Installation

**One-line install:**

```bash
curl -fsSL https://github.com/chungchihhan/fetch/releases/latest/download/Fetch.zip -o /tmp/Fetch.zip \
  && unzip -oq /tmp/Fetch.zip -d /Applications \
  && xattr -cr /Applications/Fetch.app \
  && open /Applications/Fetch.app
```

Then open **System Settings → Privacy & Security → Accessibility**, click **+**, and add Fetch. This is required for the global shortcut to work.

**Prefer manual?** Download `Fetch.zip` from the [latest release](https://github.com/chungchihhan/fetch/releases/latest), unzip, drag to `/Applications`, and right-click → **Open** on first launch.


## Display Modes

Set in **Settings → General → Display Mode:**

| Mode | Description |
|------|-------------|
| **Both** | Menu bar icon + Dock icon; popover and main window stay in sync |
| **Menu Bar Only** | Classic menu bar popover, no Dock presence |
| **Window Only** | No menu bar icon; the main window is the app |


## Keyboard Shortcuts

<table>
  <tr>
    <th colspan="2">🌐 Global</th>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>⌥</kbd><kbd>F</kbd></td>
    <td>Toggle Fetch <em>(customizable in Settings)</em></td>
  </tr>
</table>

<table>
  <tr>
    <th colspan="2">🔍 Browse</th>
  </tr>
  <tr>
    <td><kbd>⌘1</kbd> – <kbd>⌘6</kbd></td>
    <td>Switch tabs</td>
  </tr>
  <tr>
    <td><kbd>↑</kbd> <kbd>↓</kbd></td>
    <td>Navigate snippets</td>
  </tr>
  <tr>
    <td><kbd>↵</kbd></td>
    <td>Copy code to clipboard</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>C</kbd></td>
    <td>Copy title + code</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>E</kbd></td>
    <td>Enter edit mode</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>N</kbd></td>
    <td>New snippet</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>D</kbd></td>
    <td>Delete focused snippet</td>
  </tr>
  <tr>
    <td><kbd>⌥</kbd><kbd>↑</kbd> <kbd>⌥</kbd><kbd>↓</kbd></td>
    <td>Move snippet up / down</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>Z</kbd> / <kbd>⌘</kbd><kbd>⇧</kbd><kbd>Z</kbd></td>
    <td>Undo / redo</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>=</kbd> / <kbd>⌘</kbd><kbd>-</kbd></td>
    <td>Increase / decrease text size</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>,</kbd></td>
    <td>Open Settings</td>
  </tr>
  <tr>
    <td><kbd>Esc</kbd></td>
    <td>Close popover</td>
  </tr>
</table>

<table>
  <tr>
    <th colspan="2">✏️ Edit</th>
  </tr>
  <tr>
    <td><kbd>Tab</kbd> / <kbd>⇧</kbd><kbd>Tab</kbd></td>
    <td>Move between title and code fields</td>
  </tr>
  <tr>
    <td><kbd>↵</kbd> / <kbd>Esc</kbd></td>
    <td>Save and exit</td>
  </tr>
  <tr>
    <td><kbd>⇧</kbd><kbd>↵</kbd></td>
    <td>Insert newline in code</td>
  </tr>
  <tr>
    <td><kbd>⌘</kbd><kbd>E</kbd></td>
    <td>Exit edit</td>
  </tr>
</table>

## License

MIT © 2026 Chih-Han Chung
