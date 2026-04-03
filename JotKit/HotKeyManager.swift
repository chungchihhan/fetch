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
