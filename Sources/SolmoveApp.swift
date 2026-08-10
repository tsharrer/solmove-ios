import SwiftUI

@main
struct SolmoveApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.lightMode ? .light : .dark)
                .tint(Palette.accent)
        }
    }
}
