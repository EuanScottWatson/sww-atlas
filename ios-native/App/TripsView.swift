import SwiftUI

private struct CountryCode: Decodable { let code: String; let name: String }
enum CountryFlags {
    static let codes: [String:String] = {
        guard let url = Bundle.main.url(forResource:"countries",withExtension:"json"), let data = try? Data(contentsOf:url), let countries = try? JSONDecoder().decode([CountryCode].self,from:data) else { return [:] }
        return Dictionary(countries.map { ($0.name.lowercased(),$0.code) },uniquingKeysWith: { first,_ in first })
    }()
    static func flag(_ name: String) -> String {
        let key = name.lowercased()
        let special = ["england":"🏴\u{e0067}\u{e0062}\u{e0065}\u{e006e}\u{e0067}\u{e007f}","scotland":"🏴\u{e0067}\u{e0062}\u{e0073}\u{e0063}\u{e0074}\u{e007f}","wales":"🏴\u{e0067}\u{e0062}\u{e0077}\u{e006c}\u{e0073}\u{e007f}","northern ireland":"🇬🇧"]
        if let flag = special[key] { return flag }
        let aliases = ["united states of america":"US","united states":"US","usa":"US","united kingdom":"GB","hong kong":"HK","macau":"MO","vatican city":"VA","turkey":"TR","south korea":"KR","russia":"RU","czech republic":"CZ"]
        guard let code = aliases[key] ?? codes[key], code.utf8.count == 2 else { return "🌐" }
        return code.unicodeScalars.compactMap { UnicodeScalar($0.value + 127397) }.map(String.init).joined()
    }
}

struct TripRow: View {
    let trip: Record
    let data: AtlasData
    var body: some View {
        HStack(alignment:.center,spacing:12) {
            VStack(alignment:.leading,spacing:5) {
                Text(trip.name).font(.headline)
                Text(data.countries(for:trip).map { "\(CountryFlags.flag($0)) \($0)" }.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Text(recordDates(trip)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength:8)
            Text(pounds(trip.number("total"))).font(.subheadline.weight(.semibold)).monospacedDigit()
        }.padding(.vertical,3)
    }
}

struct TripsView: View {
    @EnvironmentObject private var store: AtlasStore
    let data: AtlasData
    @State private var query = ""
    @State private var year: Int? = nil
    @State private var month: Int? = nil
    @State private var region = "All regions"
    @State private var status = "All trips"
    @State private var sort = "Newest"
    @State private var showingNew = false
    @State private var showingJourney = false
    private var years: [Int] { Array(Set(data.trips.map(\.year).filter { $0 > 0 })).sorted(by: >) }
    private var results: [Record] {
        let today = localDateISO(Date())
        let scoped = AtlasCalculations.scoped(data.trips, year:year, month:month)
        let rows = scoped.filter { trip in
            let hay = ([trip.name,trip.text("notes"),trip.text("locations"),trip.text("journey_name")] + data.countries(for:trip)).joined(separator:" ")
            let matchesSearch = query.trimmingCharacters(in:.whitespaces).isEmpty || hay.localizedCaseInsensitiveContains(query.trimmingCharacters(in:.whitespaces))
            let matchesRegion = region == "All regions" || trip.text("region") == region
            let matchesStatus = status == "All trips" || (status == "Upcoming" && !trip.start.isEmpty && trip.start > today) || (status == "Past" && !trip.start.isEmpty && trip.start <= today) || (status == "Undated" && trip.start.isEmpty)
            return matchesSearch && matchesRegion && matchesStatus
        }
        let filtered = year == nil ? AtlasCalculations.uniqueVisits(rows) : rows
        return filtered.sorted { a,b in
            if sort == "Name" { return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending }
            if a.start.isEmpty != b.start.isEmpty { return !a.start.isEmpty }
            return sort == "Oldest" ? a.start < b.start : a.start > b.start
        }
    }
    var body: some View {
        List {
            Section {
                HStack(spacing:8) {
                    Menu { Picker("Year",selection:$year) { Text("All years").tag(Int?.none); ForEach(years,id:\.self) { Text(String($0)).tag(Optional($0)) } } } label: { Label(year.map(String.init) ?? "All years",systemImage:"calendar").font(.subheadline) }
                    Spacer()
                    Menu { Picker("Region",selection:$region) { ForEach(["All regions","UK","Europe","Africa","North America","South America","Asia","Oceania"],id:\.self) { Text($0) } }; Picker("Status",selection:$status) { ForEach(["All trips","Upcoming","Past","Undated"],id:\.self) { Text($0) } }; Picker("Sort",selection:$sort) { ForEach(["Newest","Oldest","Name"],id:\.self) { Text($0) } }; Picker("Month",selection:$month) { Text("All months").tag(Int?.none); ForEach(1...12,id:\.self) { n in Text(Calendar.current.monthSymbols[n-1]).tag(Optional(n)) } } } label: { Label("Filter",systemImage:"line.3.horizontal.decrease.circle") }
                }
                .buttonStyle(.borderless)
            }
            Section("\(results.count) trip records") {
                if results.isEmpty { Text("No trips match these filters.").foregroundStyle(.secondary) }
                ForEach(results) { trip in
                    NavigationLink { RecordDetailView(kind:"trips",id:trip.id) } label: { TripRow(trip:trip,data:data) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Trips")
        .searchable(text:$query,prompt:"Search trips and places")
        .refreshable { await store.load() }
        .toolbar { ToolbarItem(placement:.primaryAction) { Menu { Button { showingNew = true } label: { Label("Add trip",systemImage:"plus") }; Button { showingJourney = true } label: { Label("Add multi-stop journey",systemImage:"point.topleft.down.curvedto.point.bottomright.up") } } label: { Image(systemName:"plus") }.accessibilityLabel("Add trip options") } }
        .sheet(isPresented:$showingNew) { NavigationStack { RecordEditorView(kind:"trips",record:nil,initialDate:nil) } }
        .sheet(isPresented:$showingJourney) { NavigationStack { JourneyEditorView() } }
    }
}
