import SwiftUI
import AppKit

@main
struct QwenDashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("QwenDash") {
            ContentView()
                .frame(minWidth: 980, minHeight: 720)
                .preferredColorScheme(.dark)
                .environmentObject(appDelegate.hotkeyBridge)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 880)
    }
}

/// Observable ferry between `AppDelegate` (which owns the global hotkey) and
/// the view layer (which owns the `ChatViewModel`). Views attach the
/// view-model's `toggleVoice` to `onTrigger` when they appear.
@MainActor
final class HotkeyBridge: ObservableObject {
    var onTrigger: (() -> Void)?
    fileprivate func fire() { onTrigger?() }
}

/// SPM executable targets launch as "prohibited" / accessory processes by
/// default, which means the window never becomes key and `TextEditor`
/// silently drops keystrokes. Promote the process to a regular GUI app,
/// force-focus the first window, and install our voice hotkey.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyBridge = HotkeyBridge()
    private let voiceHotkey = VoiceHotkey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.makeMain()
            }

            // ⌥-Space anywhere on the system toggles voice capture. Carbon's
            // RegisterEventHotKey (via the HotKey package) doesn't require
            // Accessibility permission.
            self?.voiceHotkey.install { [weak self] in
                self?.hotkeyBridge.fire()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
