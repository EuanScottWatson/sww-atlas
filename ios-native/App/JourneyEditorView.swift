import SwiftUI

private struct StopDraft: Identifiable {
    let id = UUID()
    var name = "", country = "", accommodation = "", region = "Europe"
    var start = Date(), end = Date()
    var dayTrip = false
}
struct JourneyEditorView: View {
    @EnvironmentObject private var store: AtlasStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "", travel = "", flights = "", leave = ""
    @State private var stops = [StopDraft(),StopDraft()]
    @State private var saving = false, confirmDiscard = false
    @State private var failure: String?
    @State private var group = "journey-\(UUID().uuidString.lowercased())"
    private let regions = ["UK","Europe","Africa","North America","South America","Asia","Oceania"]
    var body: some View {
        Form {
            Section("Journey") {
                TextField("Journey name",text:$name)
                TextField("Shared travel (£)",text:$travel).keyboardType(.decimalPad)
                TextField("Shared flights",text:$flights).keyboardType(.decimalPad)
                TextField("Shared leave days",text:$leave).keyboardType(.decimalPad)
            }
            ForEach($stops) { $stop in
                Section("Stop") {
                    TextField("Destination",text:$stop.name)
                    TextField("Country",text:$stop.country)
                    DatePicker("Start",selection:$stop.start,displayedComponents:.date)
                    DatePicker("End",selection:$stop.end,displayedComponents:.date)
                    TextField("Accommodation (£)",text:$stop.accommodation).keyboardType(.decimalPad)
                    Picker("Region",selection:$stop.region) { ForEach(regions,id:\.self) { Text($0) } }
                    Toggle("Day trip",isOn:$stop.dayTrip)
                    if stops.count > 2 { Button("Remove stop",role:.destructive) { let id=stop.id; stops.removeAll { $0.id == id } } }
                }
            }
            Section { Button { stops.append(StopDraft()) } label: { Label("Add another stop",systemImage:"plus") }; Text("You can add map places to each stop after saving.").font(.footnote).foregroundStyle(.secondary) }
            if let failure { Section { Text(failure).foregroundStyle(.red) } }
            Section { Button(saving ? "Saving…" : "Save journey") { Task { await save() } }.disabled(saving) }
        }
        .navigationTitle("New journey").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { confirmDiscard=true } } }
        .interactiveDismissDisabled()
        .confirmationDialog("Discard your changes?",isPresented:$confirmDiscard,titleVisibility:.visible) { Button("Discard changes",role:.destructive) { dismiss() }; Button("Keep editing",role:.cancel) {} }
    }
    private func iso(_ date:Date) -> String { let c=Calendar.current.dateComponents([.year,.month,.day],from:date); return String(format:"%04d-%02d-%02d",c.year ?? 0,c.month ?? 0,c.day ?? 0) }
    private func number(_ text:String) throws -> Double? { if text.trimmingCharacters(in:.whitespaces).isEmpty { return nil }; guard let value=Double(text),value.isFinite,value>=0 else { throw AtlasError.message("Enter valid, positive numbers for costs and counts.") }; return value }
    private func save() async {
        do {
            guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw AtlasError.message("Enter a journey name.") }
            let sharedTravel=try number(travel), sharedFlights=try number(flights), sharedLeave=try number(leave)
            var records: [JSONValue] = []
            for (index, stop) in stops.enumerated() {
                let start=iso(stop.start), end=iso(stop.end), accommodation=try number(stop.accommodation) ?? 0
                guard !stop.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, start <= end else { throw AtlasError.message("Enter a destination and valid dates for stop \(index+1).") }
                let cost=index == 0 ? sharedTravel ?? 0 : 0
                var fields:[String:JSONValue] = ["name":.string(stop.name.trimmingCharacters(in:.whitespacesAndNewlines)),"country":.string(stop.country),"start":.string(start),"end":.string(end),"year":.number(Double(Int(start.prefix(4)) ?? 0)),"region":.string(stop.region),"group":.string(group),"journey_name":.string(name.trimmingCharacters(in:.whitespacesAndNewlines)),"trip_role":.string(stop.dayTrip ? "day-trip" : "stop"),"travel":index == 0 ? .number(cost) : .null,"accommodation":.number(accommodation),"total":.number(((cost+accommodation)*100).rounded()/100),"flights":index == 0 ? sharedFlights.map(JSONValue.number) ?? .null : .null,"leave":index == 0 ? sharedLeave.map(JSONValue.number) ?? .null : .null,"days":.null,"notes":.string(""),"review":.bool(false),"source":.string("")]
                var shared:[JSONValue]=[]
                if index == 0 { shared.append(.string("travel")); if sharedFlights != nil { shared.append(.string("flights")) }; if sharedLeave != nil { shared.append(.string("leave")) } }
                fields["shared_fields"] = .array(shared); records.append(.object(fields))
            }
            saving=true; failure=nil
            _ = try await store.post("/api/save-journey",body:["group":.string(group),"records":.array(records)])
            await store.load(); dismiss()
        } catch { failure=error.localizedDescription }
        saving=false
    }
}
