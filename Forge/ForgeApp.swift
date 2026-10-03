import SwiftUI

@main
struct ForgeApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .environment(\.calendar, GymCalendar.calendar)
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Overview", systemImage: "chart.xyaxis.line") }
            SessionsView().tabItem { Label("Sessions", systemImage: "calendar") }
            ProgramView().tabItem { Label("Program", systemImage: "list.bullet.rectangle") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .alert("Local data", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
