# JotDown — Design Spec
**Date:** 2026-04-03

## Overview

JotDown is a lightweight macOS menu bar app for storing and quickly accessing code snippets. It is purpose-built for developers who want a fast, keyboard-driven place to save often-used bash commands and shell snippets — without the overhead of a full notes app.

---

## Goals

- Instant access from anywhere via a global hotkey (⌘J)
- Zero friction: navigate and copy snippets without touching the mouse
- Low memory footprint — native Swift/SwiftUI, no Electron
- Minimal UI — transparent, unobtrusive, developer-aesthetic

---

## Technology

| Concern | Choice |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Syntax highlighting | [Highlightr](https://github.com/raspu/Highlightr) (SPM) — wraps highlight.js |
| Global hotkey | [HotKey](https://github.com/soffes/HotKey) (SPM) |
| Window type | `NSStatusItem` + `NSPopover` (default), detachable to `NSPanel` |
| Storage | JSON files in `~/.config/jotdown/` |

---

## Architecture

**Process type:** `LSUIElement` — menu bar only, no Dock icon.

### Components

**`AppDelegate`**
Owns the `NSStatusItem` (menu bar icon) and `NSPopover`. Handles show/hide toggling and detach to panel mode. Entry point for all window lifecycle.

**`HotKeyManager`**
Registers the global ⌘J shortcut via the `HotKey` package. Fires even when JotDown is not the active app.

**`SnippetStore`**
`@Observable` data layer. Holds 6 tabs in memory as arrays of `Snippet` objects. Responsible for loading from and saving to disk. Saves are atomic (write to temp file, then rename).

**`PopoverContentView`**
Root SwiftUI view rendered inside the popover or panel. Composes the tab bar, snippet list, and bottom hint bar.

**`SnippetListView`**
Manages keyboard navigation (↑↓ arrow keys), focus index, and edit state. Intercepts key events to implement the browse/edit mode state machine.

**`SnippetRowView`**
Renders a single snippet. Switches between browse presentation (dimmed or focused) and inline-edit presentation (yellow border, editable title + code fields) based on whether it is the currently focused+editing row.

### Window Modes

- **Popover (default):** `NSPopover` anchored to the `NSStatusItem` button. Opens flush with the menu bar, no arrow.
- **Floating panel:** Borderless `NSPanel` pinned to the top-right corner of the screen. Toggled via ⌘P or a button in the UI. Behaves like a regular window — does not auto-dismiss on click-away.

---

## Data Model

### Storage layout

```
~/.config/jotdown/
  tab1.json
  tab2.json
  tab3.json
  tab4.json
  tab5.json
  tab6.json
```

### Snippet schema

```json
[
  {
    "id": "uuid-string",
    "title": "Echo hello",
    "code": "echo \"hello\"",
    "language": "bash"
  }
]
```

- `id` — UUID, generated on creation, used as stable identity for list diffing
- `title` — plain string, displayed with a `#` prefix (markdown heading style)
- `code` — raw code string passed to Highlightr for rendering
- `language` — Highlightr language identifier, defaults to `"bash"`

### Save strategy

Saves trigger on:
- Esc (exit edit mode)
- ↑↓ (exit edit mode via navigation)
- App quit / popover close

Writes are atomic: serialize to a temp file in the same directory, then `rename()` to the target path to prevent partial writes.

---

## UI Design

### Visual style

- **Background:** Frosted glass — `rgba(15,15,25,0.6)` with `NSVisualEffectView` blur underneath
- **Window:** Rounded corners (14px), no popover arrow, no title bar in popover mode
- **Color palette:** Catppuccin Mocha-inspired — blue accents (`#89b4fa`), green strings (`#a6e3a1`), red flags (`#f38ba8`), purple keywords (`#cba6f7`)

### Layout

```
┌─────────────────────────────────┐
│   ⌘1  ⌘2  ⌘3  ⌘4  ⌘5  ⌘6      │  ← centered pill tab bar
├─────────────────────────────────┤
│ # Snippet title                 │  ← unfocused: dimmed
│ ┌─────────────────────────────┐ │
│ │ code block                  │ │
│ └─────────────────────────────┘ │
│                                 │
│ # Snippet title          ←focus │  ← focused: blue border
│ ┌─────────────────────────────┐ │
│ │ code block                  │ │
│ └─────────────────────────────┘ │
│                                 │
│ # Snippet title                 │  ← unfocused: dimmed
│ ┌─────────────────────────────┐ │
│ │ code block                  │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│  ↑↓ navigate · ↵ edit · ⌘C copy · ⌘N new · ⌘D delete  │
└─────────────────────────────────┘
```

### Snippet states

| State | Appearance |
|---|---|
| Unfocused | Dimmed text and code, no border |
| Focused (browse) | Full opacity, blue border (`rgba(137,180,250,0.35)`) |
| Editing (inline) | Yellow border (`rgba(249,226,175,0.3)`), title and code are editable fields |

### Inline editing

When the user presses Enter on a focused snippet:
- The snippet row transitions to edit mode in place — the list remains visible
- Title becomes an editable text field (cursor placed at end), displayed as `# <editable text>`
- Code block becomes an editable multiline text view
- Tab switches focus between the title field and the code field
- Bottom bar changes to: `Tab switch fields · ↑↓ or Esc to save & exit edit`

---

## Keyboard Shortcuts

| Shortcut | Context | Action |
|---|---|---|
| ⌘J | Global | Show / hide JotDown |
| Esc | Browse | Close popover / panel |
| ↑ / ↓ | Browse | Move focus between snippets |
| Enter | Browse | Enter inline edit on focused snippet |
| ⌘C | Browse | Copy focused snippet's code to clipboard |
| ⌘N | Browse | Add new empty snippet at bottom of list |
| ⌘D | Browse | Delete focused snippet |
| ⌘1 – ⌘6 | Browse | Switch to tab N |
| Tab | Edit | Switch between title and code field |
| ↑ / ↓ | Edit | Save changes, exit edit, move focus |
| Esc | Edit | Save changes, exit edit, stay on snippet |

---

## Out of Scope

- Markdown rendering (bold, italics, lists) — snippets are title + code only
- Tab renaming
- Cloud sync or iCloud backup
- Search / filter
- Snippet reordering via drag-and-drop (may add later)
- Multi-line titles
