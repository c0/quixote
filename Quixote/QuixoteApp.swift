import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "quixote-swift" }) else { return }
        // Handle deep links here
    }
}

@main
struct QuixoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                // Handled by WorkspaceViewModel via toolbar button;
                // expose Cmd+O here by posting to the active window
                Button("Open File…") {
                    NotificationCenter.default.post(name: .openFilePicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            Text("Settings coming in AO-5")
                .padding()
                .frame(width: 300, height: 200)
        }
    }
}

extension Notification.Name {
    static let openFilePicker = Notification.Name("QuixoteOpenFilePicker")
}
