import SwiftUI

@main
struct FetchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All window management is in AppDelegate.
        // Settings scene prevents SwiftUI from quitting when last window closes.
        Settings { EmptyView() }
    }
}
