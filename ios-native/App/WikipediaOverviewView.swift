import SwiftUI

struct WikipediaOverviewView: View {
    @EnvironmentObject private var store: AtlasStore
    let name: String
    var country = ""
    var latitude: Double?
    var longitude: Double?
    @State private var overview: [String:JSONValue]?
    @State private var loading = true
    @State private var error = false

    private var searchURL: URL? {
        var components = URLComponents(string: "https://en.wikipedia.org/wiki/Special:Search")
        components?.queryItems = [URLQueryItem(name: "search", value: [name, country].filter { !$0.isEmpty }.joined(separator: " "))]
        return components?.url
    }
    var body: some View {
        Section("About \(name)") {
            if loading {
                ProgressView("Loading from Wikipedia…")
            } else if let extract = overview?["extract"]?.string, !extract.isEmpty {
                if let title = overview?["title"]?.string, title != name { Text(title).font(.headline) }
                Text(extract)
                Text("Source: Wikipedia · CC BY-SA 4.0").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(error ? "Could not load the overview. Check your connection and try again." : "No overview found for this place.").foregroundStyle(.secondary)
                Button("Try again") { Task { await load() } }
            }
            if let address = overview?["url"]?.string, let url = URL(string: address), url.scheme == "https", url.host == "en.wikipedia.org" {
                Link("Open Wikipedia", destination: url)
            } else if let searchURL {
                Link("Search Wikipedia", destination: searchURL)
            }
        }
        .task(id: "\(name)|\(country)|\(latitude.map { String($0) } ?? "")|\(longitude.map { String($0) } ?? "")") { await load() }
    }
    @MainActor private func load() async {
        loading = true; error = false; overview = nil
        defer { loading = false }
        var components = URLComponents(); components.path = "/api/place"
        var items = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "country", value: country)]
        if let latitude, let longitude {
            items.append(URLQueryItem(name: "lat", value: String(latitude)))
            items.append(URLQueryItem(name: "lon", value: String(longitude)))
        }
        components.queryItems = items
        do {
            guard let path = components.string, let result = try await store.fetch(path, timeout: 40).object else {
                error = true; return
            }
            overview = result
        } catch { self.error = true }
    }
}
