import SwiftUI
import MapKit

struct RecordEditorView: View {
    @EnvironmentObject private var store: AtlasStore
    @Environment(\.dismiss) private var dismiss
    let kind: String
    let record: Record?
    @State private var draft: [String:JSONValue]
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasStart: Bool
    @State private var hasEnd: Bool
    @State private var query = ""
    @State private var searchResults: [JSONValue] = []
    @State private var places: [[String:JSONValue]]
    @State private var placesChanged = false
    @State private var showMap = false
    @State private var region = MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:51,longitude:0),span:MKCoordinateSpan(latitudeDelta:30,longitudeDelta:30))
    @State private var pinName = ""
    @State private var failure: String?
    @State private var saving = false
    @State private var confirmDiscard = false
    private var isTrip: Bool { kind == "trips" }
    init(kind: String, record: Record?, initialDate: Date?) {
        self.kind = kind; self.record = record
        let date = initialDate ?? Date()
        _draft = State(initialValue:record?.fields ?? [:])
        _startDate = State(initialValue:localDate(fromISO:record?.start ?? "") ?? date)
        _endDate = State(initialValue:localDate(fromISO:record?.end ?? "") ?? date)
        _hasStart = State(initialValue:record == nil ? initialDate != nil : !(record?.start.isEmpty ?? true))
        _hasEnd = State(initialValue:record == nil ? initialDate != nil : !(record?.end.isEmpty ?? true))
        _places = State(initialValue:[])
    }
    private func string(_ key:String) -> Binding<String> { Binding(get:{ draft[key]?.string ?? "" },set:{ draft[key] = .string($0) }) }
    private func number(_ key:String) -> Binding<String> { Binding(get:{ if let value=draft[key]?.number { return String(value) }; return draft[key]?.string ?? "" },set:{ draft[key] = .string($0) }) }
    private var groups: [Record] {
        var seen = Set<String>()
        return (store.data?.trips ?? []).filter { let group=$0.text("group"); return !group.isEmpty && seen.insert(group).inserted }
    }
    var body: some View {
        Form {
            Section(isTrip ? "Trip" : "Event") {
                TextField(isTrip ? "Destination" : "Event name",text:string("name"))
                if isTrip { TextField("Country or countries",text:string("country")) }
                Toggle("Start date",isOn:$hasStart)
                if hasStart { DatePicker("Start",selection:$startDate,displayedComponents:.date) }
                Toggle("End date",isOn:$hasEnd)
                if hasEnd { DatePicker("End",selection:$endDate,displayedComponents:.date) }
                if !isTrip { Picker("Type",selection:string("kind")) { Text("Personal event").tag(""); Text("Personal event").tag("event"); Text("Calendar context").tag("context") } }
            }
            if isTrip {
                Section("Costs and time") {
                    TextField("Allocation year",text:number("year")).keyboardType(.numberPad)
                    Picker("Region",selection:string("region")) { Text("Europe").tag(""); ForEach(["UK","Europe","Africa","North America","South America","Asia","Oceania"],id:\.self) { Text($0).tag($0) } }
                    TextField("Travel (£)",text:number("travel")).keyboardType(.decimalPad)
                    TextField("Accommodation (£)",text:number("accommodation")).keyboardType(.decimalPad)
                    TextField("Recorded total (£)",text:number("total")).keyboardType(.decimalPad)
                    TextField("Flights",text:number("flights")).keyboardType(.decimalPad)
                    TextField("Recorded days",text:number("days")).keyboardType(.decimalPad)
                    TextField("Leave days",text:number("leave")).keyboardType(.decimalPad)
                }
                Section("Journey") {
                    Picker("Journey",selection:string("group")) { Text("Standalone trip").tag(""); ForEach(groups) { trip in Text(trip.text("journey_name").isEmpty ? trip.text("group") : trip.text("journey_name")).tag(trip.text("group")) } }
                    if !(draft["group"]?.string ?? "").isEmpty {
                        Picker("Stop type",selection:string("trip_role")) { Text("Stay").tag(""); Text("Stay").tag("stop"); Text("Day trip").tag("day-trip") }
                        ForEach(["travel","flights"],id:\.self) { key in
                            Toggle("Shared \(key)",isOn:Binding(get:{ (draft["shared_fields"]?.array ?? []).compactMap(\.string).contains(key) },set:{ enabled in
                                var values=(draft["shared_fields"]?.array ?? []).compactMap(\.string).filter { $0 != key }
                                if enabled { values.append(key) }
                                draft["shared_fields"] = .array(values.map(JSONValue.string))
                            }))
                        }
                    }
                }
                Section("Places") {
                    HStack { TextField("Search for a place",text:$query); Button("Search") { Task { await searchPlaces() } }.disabled(query.trimmingCharacters(in:.whitespaces).count < 2) }
                    ForEach(Array(searchResults.enumerated()),id:\.offset) { _, result in
                        if let place = result.object {
                            Button { addPlace(place) } label: { VStack(alignment:.leading) { Text(place["name"]?.string ?? "Place"); Text(place["display"]?.string ?? "").font(.caption).foregroundStyle(.secondary) } }
                        }
                    }
                    ForEach(Array(places.enumerated()),id:\.offset) { index, place in
                        HStack { Label(place["name"]?.string ?? "Place",systemImage:"mappin"); Spacer(); Button(role:.destructive) { places.remove(at:index); placesChanged=true } label: { Image(systemName:"minus.circle") }.accessibilityLabel("Remove place") }
                    }
                    Button(showMap ? "Close map" : "Choose a pin on the map") { showMap.toggle() }
                    if showMap {
                        ZStack { Map(coordinateRegion:$region).frame(height:230).clipShape(RoundedRectangle(cornerRadius:12)); Image(systemName:"mappin.circle.fill").font(.title).foregroundStyle(.tint).allowsHitTesting(false) }
                        Text("Move the map to position the pin, then name the place.").font(.caption).foregroundStyle(.secondary)
                        TextField("Place name",text:$pinName)
                        Button("Add selected place") { addPlace(["name":.string(pinName.trimmingCharacters(in:.whitespacesAndNewlines)),"lat":.number(region.center.latitude),"lon":.number(region.center.longitude)]); pinName=""; showMap=false }.disabled(pinName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    }
                }
                Section { Toggle("Needs review",isOn:Binding(get:{ draft["review"]?.bool ?? false },set:{ draft["review"] = .bool($0) })) }
            }
            Section("Notes") { TextField("Notes",text:string("notes"),axis:.vertical).lineLimit(3...8) }
            if let failure { Section { Text(failure).foregroundStyle(.red) } }
            Section { Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(saving) }
        }
        .navigationTitle(record == nil ? (isTrip ? "Add trip" : "Add event") : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { confirmDiscard=true } } }
        .interactiveDismissDisabled()
        .confirmationDialog("Discard your changes?",isPresented:$confirmDiscard,titleVisibility:.visible) { Button("Discard changes",role:.destructive) { dismiss() }; Button("Keep editing",role:.cancel) {} }
        .task { initializePlaces() }
    }
    private func initializePlaces() {
        guard let record, let data=store.data else { return }
        let location=data.place(for:record)
        if draft["country"] == nil, let country=location["country"] { draft["country"] = country }
        if let pins=location["pins"]?.array { places=pins.compactMap(\.object) }
        else if let lat=location["lat"]?.number, let lon=location["lon"]?.number { places=[["name":.string(location["label"]?.string ?? record.name),"lat":.number(lat),"lon":.number(lon)]] }
    }
    private func searchPlaces() async {
        do {
            var components=URLComponents(); components.path="/api/place-search"; components.queryItems=[URLQueryItem(name:"q",value:query)]
            searchResults = try await store.fetch(components.string ?? "").array ?? []
            if searchResults.isEmpty { failure="No places found. Try a different search." } else { failure=nil }
        } catch { failure=error.localizedDescription }
    }
    private func addPlace(_ place:[String:JSONValue]) {
        guard let name=place["name"]?.string, !name.isEmpty, let lat=place["lat"]?.number, let lon=place["lon"]?.number else { return }
        guard !places.contains(where:{ abs(($0["lat"]?.number ?? 999)-lat)<0.0001 && abs(($0["lon"]?.number ?? 999)-lon)<0.0001 }) else { return }
        places.append(["name":.string(name),"lat":.number(lat),"lon":.number(lon)]); placesChanged=true
        if (draft["country"]?.string ?? "").isEmpty, let country=place["country"]?.string { draft["country"] = .string(country) }
        searchResults=[]; query=""
    }
    private func localISO(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year,.month,.day], from:date)
        return String(format:"%04d-%02d-%02d",parts.year ?? 0,parts.month ?? 0,parts.day ?? 0)
    }
    private func save() async {
        let name=(draft["name"]?.string ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { failure="Enter a name."; return }
        let start=hasStart ? localISO(startDate) : "", end=hasEnd ? localISO(endDate) : ""
        guard start.isEmpty || end.isEmpty || end >= start else { failure="End date must be on or after start date."; return }
        guard isTrip || (!start.isEmpty && !end.isEmpty) else { failure="Choose a start and end date."; return }
        var result=draft; result["name"] = .string(name); result["start"] = start.isEmpty ? .null : .string(start); result["end"] = end.isEmpty ? .null : .string(end)
        if isTrip {
            for key in ["travel","accommodation","total","flights","days","leave","year"] {
                if let text=result[key]?.string {
                    if text.trimmingCharacters(in:.whitespaces).isEmpty { result[key] = .null }
                    else if let value=Double(text), value.isFinite, value >= 0 { result[key] = .number(value) }
                    else { failure="Enter valid, positive numbers for costs and counts."; return }
                }
            }
            if result["year"]?.number == nil, let year=Int(start.prefix(4)) { result["year"] = .number(Double(year)) }
            guard let year=result["year"]?.number, year >= 1900, year <= 2200, year.rounded() == year else { failure="Enter an allocation year."; return }
            let old=record?.fields ?? [:]
            let changed=(result["travel"]?.number ?? 0) != (old["travel"]?.number ?? 0) || (result["accommodation"]?.number ?? 0) != (old["accommodation"]?.number ?? 0)
            let totalChanged=result["total"]?.number != old["total"]?.number
            let shared=record.map { AtlasCalculations.isShared($0,key:"total",trips:store.data?.trips ?? []) } ?? false
            if (record == nil && result["total"]?.number == nil) || (record != nil && changed && !totalChanged && !shared) { result["total"] = .number((((result["travel"]?.number ?? 0)+(result["accommodation"]?.number ?? 0))*100).rounded()/100) }
            let oldGroup = record?.text("group") ?? "", group = result["group"]?.string ?? ""
            if group != oldGroup {
                result["shared_fields"] = .array([])
                if group.isEmpty { result.removeValue(forKey:"journey_name") }
                else if let match = store.data?.trips.first(where: { $0.text("group") == group && !$0.text("journey_name").isEmpty }) { result["journey_name"] = .string(match.text("journey_name")) }
                else { result.removeValue(forKey:"journey_name") }
            }
            if let record, start != record.start || end != record.end { result["calendar_confirmed"] = .bool(true) }
            if placesChanged { result["pins"] = .array(places.map(JSONValue.object)); result["locations"] = .string(places.compactMap { $0["name"]?.string }.joined(separator:"; ")); result["lat"] = .null; result["lon"] = .null }
        }
        saving=true; failure=nil
        do { _ = try await store.save(kind:kind,record:result,id:record?.id); dismiss() } catch { failure=error.localizedDescription }
        saving=false
    }
}
