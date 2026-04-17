# Fetch
**Fast, keyboard-driven code snippet manager for your Mac menu bar.**

```
      ___           ___           ___           ___           ___     
     /\  \         /\  \         /\  \         /\  \         /\__\    
    /::\  \       /::\  \        \:\  \       /::\  \       /:/  /    
   /:/\:\  \     /:/\:\  \        \:\  \     /:/\:\  \     /:/__/     
  /::\~\:\  \   /::\~\:\  \       /::\  \   /:/  \:\  \   /::\  \ ___ 
 /:/\:\ \:\__\ /:/\:\ \:\__\     /:/\:\__\ /:/__/ \:\__\ /:/\:\  /\__\
 \/__\:\ \/__/ \:\~\:\ \/__/    /:/  \/__/ \:\  \  \/__/ \/__\:\/:/  /
      \:\__\    \:\ \:\__\     /:/  /       \:\  \            \::/  / 
       \/__/     \:\ \/__/     \/__/         \:\  \           /:/  /  
                  \:\__\                      \:\__\         /:/  /   
                   \/__/                       \/__/         \/__/    
```

Fetch lives in your menu bar and lets you store, browse, and copy code snippets instantly — without leaving your keyboard.


## Features

- **6 tabs** — organize snippets by language or project
- **Syntax highlighting** — automatic code highlighting via Highlightr
- **Keyboard-first** — navigate, edit, and copy without touching the mouse
- **Global shortcut** — summon Fetch from anywhere with a customizable hotkey (default: ⌘⌥F)
- **Code wrap** — toggle line wrapping for long snippets
- **Resizable** — drag to adjust the width and height of the popover
- **Appearance** — system, light, or dark mode
- **Custom data folder** — store your snippets wherever you want
- **Customizable font sizes** — separate controls for title and code
- **Auto-update** — built-in update checker in Settings

## Installation

One-line install:

```bash
curl -fsSL https://github.com/chungchihhan/fetch/releases/latest/download/Fetch.zip -o /tmp/Fetch.zip && unzip -oq /tmp/Fetch.zip -d /Applications && xattr -cr /Applications/Fetch.app && open /Applications/Fetch.app
```

Then go to **System Settings → Privacy & Security → Accessibility**, click **+**, and add Fetch (required for the global shortcut).

Prefer to do it manually? Download **Fetch.zip** from the [latest release](https://github.com/chungchihhan/fetch/releases/latest), unzip, drag to `/Applications`, and right-click → **Open** the first time.

## Keyboard Shortcuts

| Shortcut  | Action |
|-----------|--------|
| ⌘⌥F       | Toggle Fetch (customizable in Settings) |
| ⌘1 – ⌘6   | Switch tabs |
| ↑ / ↓     | Navigate snippets |
| Enter     | Copy focused snippet |
| ⌘E        | Enter edit mode |
| Tab       | Switch between title and code while editing |
| Esc       | Cancel edit |
| ⌘N        | New snippet |
| ⌘C        | Copy focused snippet |
| ⌘D        | Delete focused snippet |
| ⌘,        | Open Settings |

## License

MIT © 2026 Chih-Han Chung
