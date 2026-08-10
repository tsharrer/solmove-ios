import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var selection = 0
    @State private var showMessages = false

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, t in
                NavigationStack {
                    Group {
                        if t.scroll { ThemedScreen { t.view } }
                        else { ZStack { Palette.bg(store.lightMode).ignoresSafeArea(); t.view } }
                    }
                    .navigationTitle(t.title)
                    .toolbar { RoleToolbar(onMessages: { showMessages = true }) }
                }
                .tabItem { Label(t.title, systemImage: t.icon) }
                .tag(idx)
            }
        }
        .sheet(isPresented: $showMessages) {
            NavigationStack { MessagesView() }.environmentObject(store)
        }
        .onAppear {
            if let r = ProcessInfo.processInfo.environment["SOLMOVE_ROLE"],
               let role = Role(rawValue: r) {
                store.setRole(role)
            }
            if let raw = ProcessInfo.processInfo.environment["SOLMOVE_TAB"], let i = Int(raw) {
                selection = min(i, tabs.count - 1)
            }
        }
    }

    private struct TabDef { let view: AnyView; let title: String; let icon: String; let scroll: Bool }

    private func def<V: View>(_ v: V, _ title: String, _ icon: String, scroll: Bool = true) -> TabDef {
        TabDef(view: AnyView(v), title: title, icon: icon, scroll: scroll)
    }

    private var tabs: [TabDef] {
        switch store.role {
        case .member:
            return [
                def(HomeView(),     "Home",     "house.fill"),
                def(DiscoverView(), "Discover", "magnifyingglass"),
                def(MapView(),      "Map",      "map.fill", scroll: false),
                def(BookingsView(), "Bookings", "calendar"),
                def(ProfileTab(),   "Profile",  "person.crop.circle.fill"),
            ]
        case .studio:
            return [
                def(StudioDashboardView(), "Studio",      "building.2.fill"),
                def(MapView(),             "Map",         "map.fill", scroll: false),
                def(InstructorsView(),     "Instructors", "figure.yoga"),
                def(EconomicsView(),       "Economics",   "chart.bar.fill"),
                def(ProfileTab(),          "Profile",     "person.crop.circle.fill"),
            ]
        case .instructor:
            return [
                def(ShiftsView(),      "Shifts",      "bolt.fill"),
                def(InstructorsView(), "Leaderboard", "trophy.fill"),
                def(MapView(),         "Map",         "map.fill", scroll: false),
                def(ProfileTab(),      "Profile",     "person.crop.circle.fill"),
            ]
        }
    }
}

// Wraps a screen with the themed background + scrolling.
struct ThemedScreen<Content: View>: View {
    @EnvironmentObject var store: Store
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        ZStack {
            Palette.bg(store.lightMode).ignoresSafeArea()
            ScrollView { content.padding(16) }
        }
    }
}

struct RoleToolbar: ToolbarContent {
    @EnvironmentObject var store: Store
    var onMessages: (() -> Void)? = nil
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 2) {
                Text("Sol").font(.headline.bold()).foregroundColor(Palette.text(store.lightMode))
                Text("move").font(.headline.bold()).foregroundStyle(Palette.brand)
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Role", selection: Binding(get: { store.role }, set: { store.setRole($0) })) {
                    ForEach(Role.allCases, id: \.self) { r in
                        Label(r.label, systemImage: r.icon).tag(r)
                    }
                }
            } label: {
                Image(systemName: store.role.icon)
            }
        }
        if store.role != .member, let onMessages {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onMessages) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { store.toggleTheme() } label: {
                Image(systemName: store.lightMode ? "sun.max.fill" : "moon.fill")
            }
        }
    }
}
