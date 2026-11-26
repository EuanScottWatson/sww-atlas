import SwiftUI

private struct CountryPlace: Identifiable {
    let name: String
    let trips: [Record]
    var id: String { name }
}

struct CountryDirectoryView: View {
    @EnvironmentObject private var store: AtlasStore
    let mode: String
    let initialData: AtlasData
    private var data: AtlasData { store.data ?? initialData }
    private var trips: [Record] {
        let today = localDateISO(Date())
        return data.trips.filter { !$0.start.isEmpty && (mode == "All" || (mode == "Visited" ? $0.start <= today : $0.start > today)) }
    }
    private var countries: [String] { Array(Set(trips.flatMap { data.countries(for: $0) })).sorted() }
    var body: some View {
        List {
            Section("\(countries.count) countries") {
                if countries.isEmpty { Text("No countries recorded for this selection.").foregroundStyle(.secondary) }
                ForEach(countries, id: \.self) { country in
                    let records = AtlasCalculations.uniqueVisits(trips.filter { data.countries(for: $0).contains(country) })
                    let count = Set(records.map { $0.text("group").isEmpty ? "trip:\($0.id)" : "journey:\($0.text("group"))" }).count
                    NavigationLink { CountryDetailView(country: country, mode: mode, initialData: data) } label: {
                        HStack {
                            Text(CountryFlags.flag(country)).font(.title2)
                            Text(country)
                            Spacer()
                            Text("\(count) \(count == 1 ? "trip" : "trips")").foregroundStyle(.secondary)
                        }
                    }.accessibilityIdentifier("country-\(country)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Countries")
    }
}

struct CountryDetailView: View {
    @EnvironmentObject private var store: AtlasStore
    let country: String
    let mode: String
    let initialData: AtlasData
    private var data: AtlasData { store.data ?? initialData }
    private var trips: [Record] {
        let today = localDateISO(Date())
        return data.trips.filter { trip in
            !trip.start.isEmpty && data.countries(for: trip).contains(country) &&
            (mode == "All" || (mode == "Visited" ? trip.start <= today : trip.start > today))
        }
    }

    private var visits: [Record] { AtlasCalculations.uniqueVisits(trips) }
    private var places: [CountryPlace] {
        var grouped: [String: [Record]] = [:]
        for trip in visits {
            let location = data.place(for: trip)
            let pins = location["pins"]?.array?.compactMap(\.object) ?? []
            var names = pins.compactMap { $0["name"]?.string }
            if names.isEmpty, let label = location["label"]?.string, !label.isEmpty { names = [label] }
            if names.isEmpty, let locationNames = trip.fields["locations"]?.string {
                names = locationNames.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if names.isEmpty, location["lat"]?.number != nil, location["lon"]?.number != nil,
               !data.countries(for: trip).contains(where: { $0.caseInsensitiveCompare(trip.name) == .orderedSame }) {
                names = [trip.name]
            }
            for name in Set(names.filter { !$0.isEmpty }) { grouped[name, default: []].append(trip) }
        }
        return grouped.map { CountryPlace(name: $0.key, trips: $0.value) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    private var firstVisit: String { visits.map(\.start).filter { !$0.isEmpty }.min() ?? "" }
    private var latestVisit: String { visits.map(\.start).filter { !$0.isEmpty }.max() ?? "" }
    private var journeyCount: Int {
        Set(visits.map { $0.text("group").isEmpty ? "trip:\($0.id)" : "journey:\($0.text("group"))" }).count
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Text(CountryFlags.flag(country)).font(.system(size: 44)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(country).font(.title2.bold())
                        Text("\(journeyCount) \(journeyCount == 1 ? "trip" : "trips") · \(places.count) recorded \(places.count == 1 ? "place" : "places")").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 5)
                LabeledContent("Days on recorded trips", value: "\(AtlasCalculations.days(visits))")
                if !firstVisit.isEmpty { LabeledContent("First visit", value: AtlasDates.display(firstVisit)) }
                if !latestVisit.isEmpty { LabeledContent("Latest visit", value: AtlasDates.display(latestVisit)) }
            }
            WikipediaOverviewView(name: country)
            Section("Recorded places · \(places.count)") {
                if places.isEmpty {
                    Text("No named places recorded yet. Add a place to a trip to see it here.").foregroundStyle(.secondary)
                } else {
                    ForEach(places) { place in
                        NavigationLink {
                            CountryPlaceVisitsView(name: place.name, country: country, tripIDs: place.trips.map(\.id), initialData: data)
                        } label: {
                            HStack {
                                Label(place.name, systemImage: "mappin")
                                Spacer()
                                Text("\(place.trips.count) \(place.trips.count == 1 ? "visit" : "visits")").foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("country-place-\(place.name)")
                    }
                }
            }
            Section("Trips") {
                ForEach(visits.sorted { $0.start > $1.start }) { trip in
                    NavigationLink { RecordDetailView(kind: "trips", id: trip.id) } label: { TripRow(trip: trip, data: data) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle(country)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CountryPlaceVisitsView: View {
    @EnvironmentObject private var store: AtlasStore
    let name: String
    let country: String
    let tripIDs: [Int]
    let initialData: AtlasData
    private var data: AtlasData { store.data ?? initialData }
    private var trips: [Record] { data.trips.filter { tripIDs.contains($0.id) } }
    var body: some View {
        List {
            WikipediaOverviewView(name: name, country: country)
            Section("Overview") {
                LabeledContent("Visits", value: "\(trips.count)")
                LabeledContent("Days on recorded trips", value: "\(AtlasCalculations.days(trips))")
                if let first = trips.map(\.start).filter({ !$0.isEmpty }).min() { LabeledContent("First visit", value: AtlasDates.display(first)) }
                if let last = trips.map(\.start).filter({ !$0.isEmpty }).max() { LabeledContent("Latest visit", value: AtlasDates.display(last)) }
            }
            Section("Your visits") {
                ForEach(trips.sorted { $0.start > $1.start }) { trip in
                    NavigationLink { RecordDetailView(kind: "trips", id: trip.id) } label: { TripRow(trip: trip, data: data) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
