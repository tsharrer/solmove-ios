import SwiftUI

@main
struct SolmoveApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            Group {
                if store.isAuthenticated {
                    RootView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(store.lightMode ? .light : .dark)
            .tint(Palette.accent)
        }
    }
}
