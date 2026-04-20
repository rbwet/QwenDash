import AppKit
import HotKey

/// Registers a system-wide hotkey that fires a voice toggle while the app
/// is in the background. Carbon's `RegisterEventHotKey` (wrapped by the
/// `HotKey` package) doesn't require Accessibility or Input Monitoring
/// permissions, which is why we prefer it over an `NSEvent` global monitor.
@MainActor
final class VoiceHotkey {
    private var hotKey: HotKey?

    /// Install the hotkey. `onTrigger` runs on the main actor every time the
    /// user presses the combination — press once to start recording, press
    /// again to stop and transcribe (the view-model toggles internally).
    func install(key: Key = .space,
                 modifiers: NSEvent.ModifierFlags = [.option],
                 onTrigger: @escaping @MainActor () -> Void) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            guard self != nil else { return }
            // Always bring QwenDash forward so the user can see the state
            // change they just triggered.
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            onTrigger()
        }
    }

    func uninstall() {
        hotKey = nil
    }
}
