import SwiftUI

@main
struct QwenDashApp: App {
    var body: some Scene {
        WindowGroup("QwenDash") {
            ContentView()
                .frame(minWidth: 980, minHeight: 720)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 880)
    }
}
