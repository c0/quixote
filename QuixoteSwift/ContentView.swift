import SwiftUI
import Sparkle

struct ContentView: View {
    let updater: SPUUpdater

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.gift")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Quixote Swift")
                .font(.title)
                .fontWeight(.semibold)

            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 8)

            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
        .padding(40)
        .frame(minWidth: 320, minHeight: 260)
    }
}
