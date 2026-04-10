# JotDown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build JotDown — a native macOS menu bar app for keyboard-driven code snippet management.

**Architecture:** `LSUIElement` SwiftUI app with `AppDelegate` owning the `NSStatusItem` and `NSPopover`. An `@Observable` `SnippetStore` holds 6 tabs of snippets in memory and persists them as JSON in `~/.config/jotdown/`. Keyboard navigation and inline editing are handled in `SnippetListView` via a custom key event interceptor.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSStatusItem`, `NSPopover`, `NSPanel`), [HotKey](https://github.com/soffes/HotKey) SPM package (global ⌘J), [Highlightr](https://github.com/raspu/Highlightr) SPM package (syntax highlighting), XCTest.

---

## File Map

```
JotDown/
├── JotDown.xcodeproj
├── JotDown/
│   ├── JotDownApp.swift              # @main, wires AppDelegate via @NSApplicationDelegateAdaptor
│   ├── AppDelegate.swift             # NSStatusItem, NSPopover, NSPanel, show/hide logic
│   ├── HotKeyManager.swift           # Global ⌘J via HotKey package
│   ├── Models/
│   │   └── Snippet.swift             # Snippet struct: id, title, code, language. Codable.
│   ├── Store/
│   │   └── SnippetStore.swift        # @Observable: 6 tabs in memory, load/save JSON atomically
│   ├── Views/
│   │   ├── PopoverContentView.swift  # Root view: tab bar + snippet list + hint bar
│   │   ├── TabBarView.swift          # Centered pill tabs ⌘1–⌘6
│   │   ├── SnippetListView.swift     # ↑↓ navigation, focus/edit state machine, key intercept
│   │   ├── SnippetRowView.swift      # One snippet row: browse/focused/editing states
│   │   ├── HighlightedCodeView.swift # NSViewRepresentable wrapping NSTextView + Highlightr
│   │   └── HintBarView.swift         # Bottom shortcut bar, adapts to browse vs edit mode
│   └── Resources/
│       ├── Assets.xcassets           # Menu bar icon (16x16 template image)
│       └── Info.plist                # LSUIElement = YES
└── JotDownTests/
    ├── SnippetTests.swift            # Codable encode/decode
    └── SnippetStoreTests.swift       # add, delete, load, save, tab switching
```

---

## Task 1: Project Setup

**Files:**
- Create: `JotDown.xcodeproj` (via Xcode GUI)
- Modify: `JotDown/Info.plist`
- Create: `JotDown/JotDownApp.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create Xcode project**

  Open Xcode → New Project → macOS → App.
  - Product Name: `JotDown`
  - Interface: SwiftUI
  - Language: Swift
  - Uncheck "Include Tests" (we'll add the test target manually for control)
  - Save to `/Users/harry_chung/Developer/Personal/jotdown/`

- [ ] **Step 2: Set macOS deployment target**

  In project settings → JotDown target → General → Minimum Deployments: `macOS 13.0`

- [ ] **Step 3: Add SPM packages**

  Xcode → File → Add Package Dependencies:
  - `https://github.com/soffes/HotKey` → Up to Next Major from `0.2.0`
  - `https://github.com/raspu/Highlightr` → Up to Next Major from `2.1.2`

  Add both to the **JotDown** target.

- [ ] **Step 4: Set LSUIElement in Info.plist**

  Add key `Application is agent (UIElement)` = `YES` (raw key: `LSUIElement`).
  This hides the Dock icon and the app menu bar.

- [ ] **Step 5: Replace JotDownApp.swift**

  ```swift
  import SwiftUI

  @main
  struct JotDownApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

      var body: some Scene {
          // All window management is in AppDelegate.
          // Settings scene prevents SwiftUI from quitting when last window closes.
          Settings { EmptyView() }
      }
  }
  ```

- [ ] **Step 6: Add JotDownTests target**

  Xcode → File → New → Target → Unit Testing Bundle.
  Name: `JotDownTests`. Make sure it links against the `JotDown` target.

- [ ] **Step 7: Add .gitignore and init git**

  ```bash
  cd /Users/harry_chung/Developer/Personal/jotdown
  cat > .gitignore << 'EOF'
  .DS_Store
  *.xcuserstate
  xcuserdata/
  .build/
  .superpowers/
  DerivedData/
  EOF
  git init
  git add .
  git commit -m "chore: initial Xcode project with HotKey and Highlightr"
  ```

---

## Task 2: Snippet Model

**Files:**
- Create: `JotDown/Models/Snippet.swift`
- Create: `JotDownTests/SnippetTests.swift`

- [ ] **Step 1: Write the failing tests**

  `JotDownTests/SnippetTests.swift`:
  ```swift
  import XCTest
  @testable import JotDown

  final class SnippetTests: XCTestCase {
      func test_snippet_defaultLanguage_isBash() {
          let s = Snippet(title: "Hello", code: "echo hi")
          XCTAssertEqual(s.language, "bash")
      }

      func test_snippet_encodeDecode_roundtrip() throws {
          let s = Snippet(id: UUID(), title: "Test", code: "ls -lah", language: "bash")
          let data = try JSONEncoder().encode(s)
          let decoded = try JSONDecoder().decode(Snippet.self, from: data)
          XCTAssertEqual(decoded.id, s.id)
          XCTAssertEqual(decoded.title, s.title)
          XCTAssertEqual(decoded.code, s.code)
          XCTAssertEqual(decoded.language, s.language)
      }

      func test_snippet_generatesUniqueIDs() {
          let a = Snippet(title: "A", code: "a")
          let b = Snippet(title: "B", code: "b")
          XCTAssertNotEqual(a.id, b.id)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect failure**

  Cmd+U in Xcode. Expected: compile error ("cannot find type 'Snippet'").

- [ ] **Step 3: Implement Snippet.swift**

  `JotDown/Models/Snippet.swift`:
  ```swift
  import Foundation

  struct Snippet: Identifiable, Codable, Equatable {
      var id: UUID
      var title: String
      var code: String
      var language: String

      init(id: UUID = UUID(), title: String, code: String, language: String = "bash") {
          self.id = id
          self.title = title
          self.code = code
          self.language = language
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

  Cmd+U. Expected: all 3 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add JotDown/Models/Snippet.swift JotDownTests/SnippetTests.swift
  git commit -m "feat: Snippet model with Codable support"
  ```

---

## Task 3: SnippetStore

**Files:**
- Create: `JotDown/Store/SnippetStore.swift`
- Create: `JotDownTests/SnippetStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

  `JotDownTests/SnippetStoreTests.swift`:
  ```swift
  import XCTest
  @testable import JotDown

  final class SnippetStoreTests: XCTestCase {
      var tmpDir: URL!
      var store: SnippetStore!

      override func setUp() {
          tmpDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
          store = SnippetStore(storageDirectory: tmpDir)
      }

      override func tearDown() {
          try? FileManager.default.removeItem(at: tmpDir)
      }

      func test_initialState_sixEmptyTabs() {
          XCTAssertEqual(store.tabs.count, 6)
          XCTAssertTrue(store.tabs.allSatisfy { $0.isEmpty })
      }

      func test_addSnippet_appendsToActiveTab() {
          store.activeTab = 0
          store.addSnippet()
          XCTAssertEqual(store.tabs[0].count, 1)
          XCTAssertEqual(store.tabs[1].count, 0)
      }

      func test_deleteSnippet_removesCorrectItem() {
          store.addSnippet()
          store.addSnippet()
          let idToDelete = store.tabs[0][0].id
          store.deleteSnippet(id: idToDelete, tab: 0)
          XCTAssertEqual(store.tabs[0].count, 1)
          XCTAssertNotEqual(store.tabs[0][0].id, idToDelete)
      }

      func test_saveAndLoad_roundtrip() throws {
          store.activeTab = 2
          store.addSnippet()
          store.tabs[2][0].title = "My command"
          store.tabs[2][0].code = "echo hi"
          store.save(tab: 2)

          let store2 = SnippetStore(storageDirectory: tmpDir)
          store2.load(tab: 2)
          XCTAssertEqual(store2.tabs[2].count, 1)
          XCTAssertEqual(store2.tabs[2][0].title, "My command")
      }

      func test_save_isAtomic_noPartialWrite() throws {
          store.addSnippet()
          store.save(tab: 0)
          let fileURL = tmpDir.appendingPathComponent("tab1.json")
          XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
      }
  }
  ```

- [ ] **Step 2: Run tests — expect failure**

  Cmd+U. Expected: compile error ("cannot find type 'SnippetStore'").

- [ ] **Step 3: Implement SnippetStore.swift**

  `JotDown/Store/SnippetStore.swift`:
  ```swift
  import Foundation
  import Observation

  @Observable
  final class SnippetStore {
      var tabs: [[Snippet]] = Array(repeating: [], count: 6)
      var activeTab: Int = 0

      private let storageDirectory: URL

      init(storageDirectory: URL = Self.defaultDirectory) {
          self.storageDirectory = storageDirectory
          loadAll()
      }

      static var defaultDirectory: URL {
          let config = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent(".config/jotdown")
          try? FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
          return config
      }

      func addSnippet() {
          tabs[activeTab].append(Snippet(title: "", code: ""))
          save(tab: activeTab)
      }

      func deleteSnippet(id: UUID, tab: Int) {
          tabs[tab].removeAll { $0.id == id }
          save(tab: tab)
      }

      func save(tab: Int) {
          let url = fileURL(for: tab)
          let tmpURL = url.deletingLastPathComponent()
              .appendingPathComponent(UUID().uuidString + ".tmp")
          do {
              let data = try JSONEncoder().encode(tabs[tab])
              try data.write(to: tmpURL, options: .atomic)
              _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
          } catch {
              try? FileManager.default.removeItem(at: tmpURL)
          }
      }

      func saveAll() {
          for i in 0..<6 { save(tab: i) }
      }

      func load(tab: Int) {
          let url = fileURL(for: tab)
          guard let data = try? Data(contentsOf: url),
                let snippets = try? JSONDecoder().decode([Snippet].self, from: data)
          else { return }
          tabs[tab] = snippets
      }

      private func loadAll() {
          for i in 0..<6 { load(tab: i) }
      }

      private func fileURL(for tab: Int) -> URL {
          storageDirectory.appendingPathComponent("tab\(tab + 1).json")
      }
  }
  ```

- [ ] **Step 4: Run tests — expect pass**

  Cmd+U. Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add JotDown/Store/SnippetStore.swift JotDownTests/SnippetStoreTests.swift
  git commit -m "feat: SnippetStore with atomic JSON persistence"
  ```

---

## Task 4: AppDelegate — StatusItem + Popover

**Files:**
- Create: `JotDown/AppDelegate.swift`

- [ ] **Step 1: Implement AppDelegate.swift**

  ```swift
  import AppKit
  import SwiftUI

  final class AppDelegate: NSObject, NSApplicationDelegate {
      var statusItem: NSStatusItem!
      var popover: NSPopover!
      var panel: NSPanel?
      let store = SnippetStore()
      var isPanel = false

      func applicationDidFinishLaunching(_ notification: Notification) {
          // Prevent Cmd+Q from quitting (menu bar apps stay alive)
          NSApp.setActivationPolicy(.accessory)

          setupStatusItem()
          setupPopover()
      }

      private func setupStatusItem() {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
          if let button = statusItem.button {
              button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "JotDown")
              button.image?.isTemplate = true
              button.action = #selector(togglePopover)
              button.target = self
          }
      }

      private func setupPopover() {
          popover = NSPopover()
          popover.contentSize = NSSize(width: 380, height: 300)
          popover.behavior = .transient      // closes on click-outside
          popover.animates = false
          popover.contentViewController = NSHostingController(
              rootView: PopoverContentView()
                  .environment(store)
                  .onReceive(NotificationCenter.default.publisher(for: .togglePanel)) { [weak self] _ in
                      self?.togglePanel()
                  }
          )
          // Remove the popover arrow
          popover.setValue(false, forKeyPath: "shouldHaveArrow")
      }

      @objc func togglePopover() {
          guard !isPanel else { panel?.makeKeyAndOrderFront(nil); return }
          if popover.isShown {
              popover.performClose(nil)
          } else {
              guard let button = statusItem.button else { return }
              popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
              popover.contentViewController?.view.window?.makeKey()
          }
      }

      func togglePanel() {
          if isPanel {
              // Switch back to popover
              panel?.close()
              panel = nil
              isPanel = false
          } else {
              // Detach to floating panel
              popover.performClose(nil)
              isPanel = true
              let hosting = NSHostingController(
                  rootView: PopoverContentView()
                      .environment(store)
                      .onReceive(NotificationCenter.default.publisher(for: .togglePanel)) { [weak self] _ in
                          self?.togglePanel()
                      }
              )
              let p = NSPanel(
                  contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                  styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                  backing: .buffered,
                  defer: false
              )
              p.contentViewController = hosting
              p.isFloatingPanel = true
              p.level = .floating
              p.isOpaque = false
              p.backgroundColor = .clear
              p.hasShadow = true
              // Pin to top-right
              if let screen = NSScreen.main {
                  let x = screen.visibleFrame.maxX - 390
                  let y = screen.visibleFrame.maxY - 310
                  p.setFrameOrigin(NSPoint(x: x, y: y))
              }
              p.makeKeyAndOrderFront(nil)
              self.panel = p
          }
      }

      func applicationWillTerminate(_ notification: Notification) {
          store.saveAll()
      }
  }

  extension Notification.Name {
      static let togglePanel = Notification.Name("JotDownTogglePanel")
  }
  ```

- [ ] **Step 2: Build and run — verify menu bar icon appears**

  Cmd+R. The app should launch with a note icon in the menu bar. Clicking it should show an empty popover (crash is OK — PopoverContentView doesn't exist yet).

- [ ] **Step 3: Commit**

  ```bash
  git add JotDown/AppDelegate.swift
  git commit -m "feat: AppDelegate with NSStatusItem and NSPopover"
  ```

---

## Task 5: HotKeyManager — Global ⌘J

**Files:**
- Create: `JotDown/HotKeyManager.swift`
- Modify: `JotDown/AppDelegate.swift`

- [ ] **Step 1: Create HotKeyManager.swift**

  ```swift
  import HotKey

  final class HotKeyManager {
      private var hotKey: HotKey?
      private let action: () -> Void

      init(action: @escaping () -> Void) {
          self.action = action
          register()
      }

      private func register() {
          hotKey = HotKey(key: .j, modifiers: .command)
          hotKey?.keyDownHandler = action
      }
  }
  ```

- [ ] **Step 2: Wire into AppDelegate**

  Add to `AppDelegate`:
  ```swift
  var hotKeyManager: HotKeyManager?
  ```

  At the end of `applicationDidFinishLaunching`:
  ```swift
  hotKeyManager = HotKeyManager { [weak self] in
      self?.togglePopover()
  }
  ```

- [ ] **Step 3: Build and test manually**

  Cmd+R. Click away from the app. Press ⌘J — popover should toggle. Press ⌘J again — should close.

- [ ] **Step 4: Commit**

  ```bash
  git add JotDown/HotKeyManager.swift JotDown/AppDelegate.swift
  git commit -m "feat: global ⌘J hotkey via HotKey package"
  ```

---

## Task 6: HighlightedCodeView (Syntax Highlighting)

**Files:**
- Create: `JotDown/Views/HighlightedCodeView.swift`

- [ ] **Step 1: Create HighlightedCodeView.swift**

  This wraps `NSTextView` to render syntax-highlighted code via Highlightr. It is non-editable in browse mode and editable in edit mode.

  ```swift
  import SwiftUI
  import Highlightr

  struct HighlightedCodeView: NSViewRepresentable {
      var code: String
      var language: String
      var isEditing: Bool
      var onCodeChange: ((String) -> Void)?

      private let highlightr: Highlightr = {
          let h = Highlightr()!
          h.setTheme(to: "atom-one-dark")
          return h
      }()

      func makeNSView(context: Context) -> NSScrollView {
          let scrollView = NSScrollView()
          let textView = NSTextView()

          textView.isRichText = false
          textView.isSelectable = true
          textView.drawsBackground = false
          textView.textContainerInset = NSSize(width: 2, height: 2)
          textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
          textView.delegate = context.coordinator

          scrollView.documentView = textView
          scrollView.hasVerticalScroller = false
          scrollView.hasHorizontalScroller = false
          scrollView.drawsBackground = false
          scrollView.borderType = .noBorder

          return scrollView
      }

      func updateNSView(_ scrollView: NSScrollView, context: Context) {
          guard let textView = scrollView.documentView as? NSTextView else { return }
          textView.isEditable = isEditing

          // Only re-highlight if code changed to avoid cursor jump during editing
          if textView.string != code {
              if let highlighted = highlightr.highlight(code, as: language) {
                  textView.textStorage?.setAttributedString(highlighted)
              } else {
                  textView.string = code
              }
          }
      }

      func makeCoordinator() -> Coordinator {
          Coordinator(onCodeChange: onCodeChange)
      }

      final class Coordinator: NSObject, NSTextViewDelegate {
          var onCodeChange: ((String) -> Void)?
          init(onCodeChange: ((String) -> Void)?) { self.onCodeChange = onCodeChange }
          func textDidChange(_ notification: Notification) {
              guard let tv = notification.object as? NSTextView else { return }
              onCodeChange?(tv.string)
          }
      }
  }
  ```

- [ ] **Step 2: Verify it compiles**

  Cmd+B. No errors expected if Highlightr is linked correctly.

- [ ] **Step 3: Commit**

  ```bash
  git add JotDown/Views/HighlightedCodeView.swift
  git commit -m "feat: HighlightedCodeView with Highlightr syntax highlighting"
  ```

---

## Task 7: HintBarView

**Files:**
- Create: `JotDown/Views/HintBarView.swift`

- [ ] **Step 1: Create HintBarView.swift**

  ```swift
  import SwiftUI

  struct HintBarView: View {
      var isEditing: Bool

      var body: some View {
          Text(isEditing
               ? "Tab switch fields · ↑↓ or Esc to save & exit"
               : "↑↓ navigate · ↵ edit · ⌘C copy · ⌘N new · ⌘D delete")
              .font(.system(size: 9, design: .monospaced))
              .foregroundStyle(.white.opacity(0.25))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.vertical, 6)
              .padding(.horizontal, 12)
              .background(Divider().padding(.bottom), alignment: .top)
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add JotDown/Views/HintBarView.swift
  git commit -m "feat: HintBarView with context-aware shortcut hints"
  ```

---

## Task 8: TabBarView

**Files:**
- Create: `JotDown/Views/TabBarView.swift`

- [ ] **Step 1: Create TabBarView.swift**

  ```swift
  import SwiftUI

  struct TabBarView: View {
      @Binding var activeTab: Int

      var body: some View {
          HStack(spacing: 4) {
              ForEach(0..<6, id: \.self) { i in
                  Button("⌘\(i + 1)") { activeTab = i }
                  .buttonStyle(TabButtonStyle(isActive: activeTab == i))
                  .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
              }
          }
          .padding(.horizontal, 12)
          .padding(.top, 10)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity)
          .overlay(Divider(), alignment: .bottom)
      }
  }

  struct TabButtonStyle: ButtonStyle {
      var isActive: Bool

      func makeBody(configuration: Configuration) -> some View {
          configuration.label
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(isActive ? Color(hex: "#89b4fa") : .white.opacity(0.28))
              .padding(.vertical, 3)
              .padding(.horizontal, 12)
              .background(
                  RoundedRectangle(cornerRadius: 6)
                      .fill(isActive ? Color(hex: "#89b4fa").opacity(0.18) : .clear)
                      .overlay(
                          RoundedRectangle(cornerRadius: 6)
                              .stroke(isActive ? Color(hex: "#89b4fa").opacity(0.35) : .clear, lineWidth: 1)
                      )
              )
      }
  }

  // Convenience hex color init
  extension Color {
      init(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let r = Double((int >> 16) & 0xff) / 255
          let g = Double((int >> 8) & 0xff) / 255
          let b = Double(int & 0xff) / 255
          self.init(red: r, green: g, blue: b)
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add JotDown/Views/TabBarView.swift
  git commit -m "feat: TabBarView with pill-style ⌘1–⌘6 tabs"
  ```

---

## Task 9: SnippetRowView

**Files:**
- Create: `JotDown/Views/SnippetRowView.swift`

- [ ] **Step 1: Create SnippetRowView.swift**

  ```swift
  import SwiftUI

  enum SnippetField: Hashable { case title, code }

  struct SnippetRowView: View {
      @Binding var snippet: Snippet
      var isFocused: Bool
      var isEditing: Bool
      var onTitleChange: (String) -> Void
      var onCodeChange: (String) -> Void

      // Drives Tab-switching: when isEditing turns true, .title is focused.
      // The user presses Tab → macOS moves to the next key view (the NSTextView
      // inside HighlightedCodeView) via the standard AppKit responder chain.
      @FocusState private var focusedField: SnippetField?

      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              // Title row: "# title"
              HStack(spacing: 4) {
                  Text("#")
                      .font(.system(size: 11, design: .monospaced))
                      .foregroundStyle(Color(hex: "#89b4fa").opacity(isFocused ? 0.6 : 0.3))
                  if isEditing {
                      TextField("", text: Binding(
                          get: { snippet.title },
                          set: { onTitleChange($0) }
                      ))
                      .font(.system(size: 11, design: .monospaced))
                      .foregroundStyle(.white.opacity(0.85))
                      .textFieldStyle(.plain)
                      .focused($focusedField, equals: .title)
                  } else {
                      Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                          .font(.system(size: 11, design: .monospaced))
                          .foregroundStyle(.white.opacity(isFocused ? 0.9 : 0.35))
                  }
              }

              // Code block. NSTextView is a natural key view successor to
              // the title TextField — Tab moves into it automatically.
              HighlightedCodeView(
                  code: snippet.code,
                  language: snippet.language,
                  isEditing: isEditing,
                  onCodeChange: isEditing ? onCodeChange : nil
              )
              .frame(minHeight: 28)
              .padding(7)
              .background(Color.black.opacity(0.4))
              .clipShape(RoundedRectangle(cornerRadius: 5))
          }
          .padding(8)
          .background(backgroundFill)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
              RoundedRectangle(cornerRadius: 8)
                  .stroke(borderColor, lineWidth: 1)
          )
          // Auto-focus title field when this row enters edit mode
          .onChange(of: isEditing) { _, editing in
              focusedField = editing ? .title : nil
          }
      }

      private var backgroundFill: Color {
          if isEditing { return Color(hex: "#f9e2af").opacity(0.05) }
          if isFocused { return Color(hex: "#89b4fa").opacity(0.07) }
          return .clear
      }

      private var borderColor: Color {
          if isEditing { return Color(hex: "#f9e2af").opacity(0.30) }
          if isFocused { return Color(hex: "#89b4fa").opacity(0.35) }
          return .clear
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add JotDown/Views/SnippetRowView.swift
  git commit -m "feat: SnippetRowView with browse/focused/editing states"
  ```

---

## Task 10: SnippetListView + Keyboard Navigation

**Files:**
- Create: `JotDown/Views/SnippetListView.swift`

- [ ] **Step 1: Create SnippetListView.swift**

  This is the core interaction view. It uses `NSViewRepresentable`-based key event interception because SwiftUI's `.onKeyPress` is limited for arrow keys / custom modifiers.

  ```swift
  import SwiftUI
  import AppKit

  struct SnippetListView: View {
      @Environment(SnippetStore.self) var store
      @State private var focusedIndex: Int? = nil
      @State private var isEditing: Bool = false

      var snippets: [Snippet] { store.tabs[store.activeTab] }

      var body: some View {
          KeyInterceptView(onKey: handleKey) {
              ScrollViewReader { proxy in
                  ScrollView(.vertical, showsIndicators: false) {
                      LazyVStack(spacing: 10) {
                          ForEach(Array(snippets.enumerated()), id: \.element.id) { i, snippet in
                              SnippetRowView(
                                  snippet: binding(for: i),
                                  isFocused: focusedIndex == i,
                                  isEditing: isEditing && focusedIndex == i,
                                  onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
                                  onCodeChange: { store.tabs[store.activeTab][i].code = $0 }
                              )
                              .id(i)
                              .onTapGesture { focusedIndex = i }
                          }
                      }
                      .padding(.horizontal, 12)
                      .padding(.vertical, 10)
                  }
                  .onChange(of: focusedIndex) { _, idx in
                      if let idx { proxy.scrollTo(idx, anchor: .center) }
                  }
              }
          }
          .onChange(of: store.activeTab) { _, _ in
              focusedIndex = snippets.isEmpty ? nil : 0
              isEditing = false
          }
      }

      private func binding(for index: Int) -> Binding<Snippet> {
          Binding(
              get: { store.tabs[store.activeTab][index] },
              set: { store.tabs[store.activeTab][index] = $0 }
          )
      }

      private func handleKey(_ event: NSEvent) -> Bool {
          let tab = store.activeTab

          if isEditing {
              switch event.keyCode {
              case 53: // Esc — save and exit edit
                  isEditing = false
                  NotificationCenter.default.post(name: .editModeChanged, object: false)
                  store.save(tab: tab)
                  return true
              case 125, 126: // ↓↑ — save, exit edit, move focus
                  isEditing = false
                  NotificationCenter.default.post(name: .editModeChanged, object: false)
                  store.save(tab: tab)
                  moveFocus(by: event.keyCode == 125 ? 1 : -1)
                  return true
              case 48: // Tab — let it pass through to SwiftUI text fields
                  return false
              default:
                  return false // let typing pass through to text fields
              }
          }

          // Browse mode
          switch event.keyCode {
          case 125: moveFocus(by: 1); return true        // ↓
          case 126: moveFocus(by: -1); return true       // ↑
          case 36:  enterEditMode(); return true         // Enter
          case 53:  closeApp(); return true              // Esc
          case 8 where event.modifierFlags.contains(.command): // ⌘C
              copyFocusedCode(); return true
          case 45 where event.modifierFlags.contains(.command): // ⌘N
              addSnippet(); return true
          case 2 where event.modifierFlags.contains(.command):  // ⌘D
              deleteFocused(); return true
          default: return false
          }
      }

      private func moveFocus(by delta: Int) {
          guard !snippets.isEmpty else { return }
          let current = focusedIndex ?? (delta > 0 ? -1 : snippets.count)
          focusedIndex = max(0, min(snippets.count - 1, current + delta))
      }

      private func enterEditMode() {
          guard focusedIndex != nil else { return }
          isEditing = true
          NotificationCenter.default.post(name: .editModeChanged, object: true)
      }

      private func copyFocusedCode() {
          guard let i = focusedIndex, i < snippets.count else { return }
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(snippets[i].code, forType: .string)
      }

      private func addSnippet() {
          store.addSnippet()
          focusedIndex = snippets.count - 1
          isEditing = true
      }

      private func deleteFocused() {
          guard let i = focusedIndex, i < snippets.count else { return }
          let id = snippets[i].id
          store.deleteSnippet(id: id, tab: store.activeTab)
          if snippets.isEmpty {
              focusedIndex = nil
          } else {
              focusedIndex = max(0, i - 1)
          }
      }

      private func closeApp() {
          NotificationCenter.default.post(name: NSPopover.willCloseNotification, object: nil)
          NSApp.hide(nil)
      }
  }

  // NSViewRepresentable that intercepts key events before SwiftUI sees them
  struct KeyInterceptView<Content: View>: NSViewRepresentable {
      let onKey: (NSEvent) -> Bool
      let content: Content

      init(onKey: @escaping (NSEvent) -> Bool, @ViewBuilder content: () -> Content) {
          self.onKey = onKey
          self.content = content()
      }

      func makeNSView(context: Context) -> KeyCatchingNSView {
          let v = KeyCatchingNSView()
          v.onKey = onKey
          let host = NSHostingView(rootView: content)
          host.translatesAutoresizingMaskIntoConstraints = false
          v.addSubview(host)
          NSLayoutConstraint.activate([
              host.topAnchor.constraint(equalTo: v.topAnchor),
              host.bottomAnchor.constraint(equalTo: v.bottomAnchor),
              host.leadingAnchor.constraint(equalTo: v.leadingAnchor),
              host.trailingAnchor.constraint(equalTo: v.trailingAnchor),
          ])
          return v
      }

      func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
          nsView.onKey = onKey
      }
  }

  final class KeyCatchingNSView: NSView {
      var onKey: ((NSEvent) -> Bool)?
      override var acceptsFirstResponder: Bool { true }
      override func keyDown(with event: NSEvent) {
          if onKey?(event) != true { super.keyDown(with: event) }
      }
  }
  ```

- [ ] **Step 2: Add notification name extensions at bottom of SnippetListView.swift**

  Append to the bottom of `JotDown/Views/SnippetListView.swift` so Task 10 compiles standalone:

  ```swift
  // Notification names used across SnippetListView and PopoverContentView
  extension Notification.Name {
      static let editModeChanged = Notification.Name("JotDownEditModeChanged")
      static let popoverDidOpen  = Notification.Name("JotDownPopoverDidOpen")
  }
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add JotDown/Views/SnippetListView.swift
  git commit -m "feat: SnippetListView with keyboard navigation and edit state machine"
  ```

---

## Task 11: PopoverContentView — Root View + Frosted Glass

**Files:**
- Create: `JotDown/Views/PopoverContentView.swift`

- [ ] **Step 1: Create PopoverContentView.swift**

  ```swift
  import SwiftUI

  struct PopoverContentView: View {
      @Environment(SnippetStore.self) var store
      @State private var isEditing = false

      var body: some View {
          ZStack {
              // Frosted glass background
              VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                  .ignoresSafeArea()

              VStack(spacing: 0) {
                  TabBarView(activeTab: Binding(
                      get: { store.activeTab },
                      set: { store.activeTab = $0 }
                  ))

                  SnippetListView()

                  HintBarView(isEditing: isEditing)
              }
          }
          .frame(width: 380, height: 300)
          .background(.clear)
          // Propagate edit state up for HintBarView
          .onReceive(NotificationCenter.default.publisher(for: .editModeChanged)) { note in
              isEditing = note.object as? Bool ?? false
          }
      }
  }

  // NSVisualEffectView wrapper for frosted glass
  struct VisualEffectView: NSViewRepresentable {
      var material: NSVisualEffectView.Material
      var blendingMode: NSVisualEffectView.BlendingMode

      func makeNSView(context: Context) -> NSVisualEffectView {
          let v = NSVisualEffectView()
          v.material = material
          v.blendingMode = blendingMode
          v.state = .active
          return v
      }

      func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
  }

  // Note: editModeChanged and popoverDidOpen are defined in SnippetListView.swift (Task 10).
  ```

- [ ] **Step 2: Build and run — full app smoke test**

  Cmd+R. Press ⌘J — popover should open with frosted glass, 6 tabs, empty list, and shortcut bar.

  Press ⌘N — a new snippet row should appear in edit mode with cursor in the title field. The hint bar must show `Tab switch fields · ↑↓ or Esc to save & exit`.

  Press Tab — focus must move to the code field (cursor appears in the code block). Press Tab again — focus returns to the title field. If Tab does not move between fields, check that `SnippetRowView` uses `@FocusState` to manage focus between the two `TextField`/`NSTextView` elements, and that `KeyInterceptView` returns `false` for keyCode 48 (Tab) in edit mode.

  Type some bash code. Press Esc — should exit edit and show highlighted code. The hint bar must return to `↑↓ navigate · ↵ edit · ⌘C copy · ⌘N new · ⌘D delete`.

- [ ] **Step 3: Commit**

  ```bash
  git add JotDown/Views/PopoverContentView.swift
  git commit -m "feat: PopoverContentView with frosted glass and full layout"
  ```

---

## Task 12: Menu Bar Icon + App Icon

**Files:**
- Modify: `JotDown/Resources/Assets.xcassets`

- [ ] **Step 1: Add a template menu bar icon**

  In Xcode, open `Assets.xcassets`. Add a new Image Set named `MenuBarIcon`.
  - Provide a 16x16 and 32x32 (2x) PDF or PNG of a simple note/pencil icon
  - Set Render As: `Template Image` (so it adapts to dark/light menu bar automatically)

  In `AppDelegate.setupStatusItem`, update:
  ```swift
  button.image = NSImage(named: "MenuBarIcon")
  button.image?.isTemplate = true
  ```

  Alternatively keep the SF Symbol `note.text` — it works out of the box.

- [ ] **Step 2: Commit**

  ```bash
  git add JotDown/Resources/Assets.xcassets
  git commit -m "chore: menu bar icon asset"
  ```

---

## Task 13: Panel Detach Mode (⌘P)

**Files:**
- Modify: `JotDown/Views/HintBarView.swift`
- Modify: `JotDown/Views/PopoverContentView.swift`

- [ ] **Step 1: Replace HintBarView.swift with the detach-button version**

  Fully replace `JotDown/Views/HintBarView.swift` with:

  ```swift
  import SwiftUI

  struct HintBarView: View {
      var isEditing: Bool

      var body: some View {
          HStack(spacing: 0) {
              Spacer()
              Text(isEditing
                   ? "Tab switch fields · ↑↓ or Esc to save & exit"
                   : "↑↓ navigate · ↵ edit · ⌘C copy · ⌘N new · ⌘D delete")
                  .font(.system(size: 9, design: .monospaced))
                  .foregroundStyle(.white.opacity(0.25))
              Spacer()
              Button {
                  NotificationCenter.default.post(name: .togglePanel, object: nil)
              } label: {
                  Image(systemName: "arrow.up.left.and.arrow.down.right")
                      .font(.system(size: 9))
                      .foregroundStyle(.white.opacity(0.2))
              }
              .buttonStyle(.plain)
              .keyboardShortcut("p", modifiers: .command)
              .padding(.trailing, 12)
          }
          .padding(.vertical, 6)
          .overlay(Divider(), alignment: .top)
      }
  }
  ```

- [ ] **Step 2: Build and test panel mode**

  Cmd+R. Open the popover (⌘J). Press ⌘P or click the expand icon. The popover should close and a borderless floating panel should appear at the top-right. Press ⌘P again — panel closes, popover returns.

- [ ] **Step 3: Commit**

  ```bash
  git add JotDown/Views/HintBarView.swift JotDown/Views/PopoverContentView.swift
  git commit -m "feat: ⌘P toggle between popover and floating panel"
  ```

---

## Task 14: Polish & Edge Cases

**Files:**
- Modify: `JotDown/Views/SnippetListView.swift`
- Modify: `JotDown/AppDelegate.swift`

- [ ] **Step 1: Handle empty tab state**

  In `SnippetListView.body`, replace the `KeyInterceptView { ScrollViewReader { ... } }` block with an if-else so the empty state fills the same space:

  ```swift
  KeyInterceptView(onKey: handleKey) {
      if snippets.isEmpty {
          Text("Press ⌘N to add a snippet")
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.white.opacity(0.2))
              .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
          ScrollViewReader { proxy in
              // ... existing ScrollView code unchanged ...
          }
      }
  }
  ```

  The `KeyInterceptView` wrapper stays in place so ⌘N still works even when the list is empty.

- [ ] **Step 2: Save on popover close**

  In `AppDelegate`, observe popover will-close:
  ```swift
  // In setupPopover():
  NotificationCenter.default.addObserver(
      self,
      selector: #selector(popoverWillClose),
      name: NSPopover.willCloseNotification,
      object: popover
  )

  @objc func popoverWillClose() {
      store.saveAll()
  }
  ```

- [ ] **Step 3: Auto-focus first snippet on open**

  In `AppDelegate.togglePopover`, post `.popoverDidOpen` after showing:
  ```swift
  popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  popover.contentViewController?.view.window?.makeKey()
  NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
  ```

  In `SnippetListView.body`, add an `onReceive` to auto-select the first row:
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
      if focusedIndex == nil, !snippets.isEmpty {
          focusedIndex = 0
      }
  }
  ```

  (`popoverDidOpen` is already defined in the `Notification.Name` extension added in Task 10 Step 2.)

- [ ] **Step 4: Full integration test**

  Manual checklist:
  - [ ] ⌘J opens / closes popover
  - [ ] ⌘1–⌘6 switch tabs, data is separate
  - [ ] ⌘N adds snippet, enters edit mode, Tab works
  - [ ] Esc saves and exits edit mode
  - [ ] ↑↓ navigate, saves on exit from edit
  - [ ] ⌘C copies code to clipboard (paste in Terminal to verify)
  - [ ] ⌘D deletes focused snippet
  - [ ] Quit and relaunch — snippets persist in `~/.config/jotdown/`
  - [ ] ⌘P opens floating panel, ⌘P again returns to popover

- [ ] **Step 5: Final commit**

  ```bash
  git add -A
  git commit -m "feat: polish — empty state, save on close, auto-focus"
  ```

---

## Build & Run Reference

```bash
# Open in Xcode
open /Users/harry_chung/Developer/Personal/jotdown/JotDown.xcodeproj

# Run tests
# Cmd+U in Xcode, or:
xcodebuild test \
  -project JotDown.xcodeproj \
  -scheme JotDown \
  -destination 'platform=macOS'

# Build release
xcodebuild \
  -project JotDown.xcodeproj \
  -scheme JotDown \
  -configuration Release \
  -archivePath build/JotDown.xcarchive \
  archive
```
