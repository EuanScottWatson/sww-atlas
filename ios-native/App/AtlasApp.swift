import SwiftUI
import UIKit

@main
struct AtlasApp: App {
    @StateObject private var store = AtlasStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            AtlasRoot()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.atlasAccent)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .task { await store.load() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { Task { await store.load() } }
                }
        }
    }
}

struct AtlasRoot: View {
    @EnvironmentObject private var store: AtlasStore
    @State private var tripPath: [Int] = []
    var body: some View {
        Group {
            if let data = store.data {
                TabView {
                    NavigationStack(path: $tripPath) { TripsView(data: data) }.tabItem { Label("Trips",systemImage:"list.bullet.rectangle") }
                    NavigationStack { StatisticsView(data: data) }.tabItem { Label("Statistics",systemImage:"chart.bar.xaxis") }
                    NavigationStack { PlacesView(data: data) }.tabItem { Label("Map",systemImage:"map") }
                    NavigationStack { CalendarView(data: data) }.tabItem { Label("Calendar",systemImage:"calendar") }
                }
                .overlay(alignment: .top) {
                    if let error = store.error {
                        Text(error).font(.footnote).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding()
                    }
                }
            } else if store.loading {
                ProgressView("Loading your travel record…")
            } else {
                VStack(spacing:16) {
                    Image(systemName:"wifi.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Can't reach your travel server").font(.headline)
                    Text(store.error ?? "Connect to your home network or Tailscale and try again.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.load() } }.buttonStyle(.borderedProminent)
                }.padding(30)
            }
        }
    }
}

struct KeyboardDismissToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissAtlasKeyboard() }
            }
        }
    }
}

func dismissAtlasKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
