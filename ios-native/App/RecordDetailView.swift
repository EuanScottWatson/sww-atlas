import SwiftUI

struct RecordDetailView: View {
    @EnvironmentObject private var store: AtlasStore
    @Environment(\.dismiss) private var dismiss
    let kind: String
    let id: Int
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var failure: String?
    private var record: Record? { (kind == "trips" ? store.data?.trips : store.data?.events)?.first { $0.id == id } }
    var body: some View {
        Group {
            if let record, let data=store.data {
                List {
                    Section {
                        LabeledContent("Dates",value:recordDates(record))
                        if kind == "trips" {
                            LabeledContent("Country",value:data.countries(for:record).joined(separator:", "))
                            valueRow("Travel",record,"travel",money:true,data:data)
                            valueRow("Accommodation",record,"accommodation",money:true,data:data)
                            valueRow("Recorded total",record,"total",money:true,data:data)
                            valueRow("Flights",record,"flights",money:false,data:data)
                            valueRow("Recorded days",record,"days",money:false,data:data)
                            valueRow("Leave days",record,"leave",money:false,data:data)
                            LabeledContent("Worksheet year",value:record.year == 0 ? "—" : String(record.year))
                        }
                    }
                    if kind == "trips" {
                        let group=record.text("group")
                        let stops=AtlasCalculations.uniqueVisits(data.trips.filter { !group.isEmpty && $0.text("group") == group })
                        if stops.count > 1 {
                            let costs=AtlasCalculations.uniqueCosts(stops)
                            Section(record.text("journey_name").isEmpty ? "Journey" : record.text("journey_name")) {
                                LabeledContent("Recorded total",value:costs.contains { $0.number("total") != nil } ? pounds(AtlasCalculations.sum(costs,"total")) : "Not recorded")
                                Text("Shared amounts are counted once across the journey.").font(.footnote).foregroundStyle(.secondary)
                                ForEach(stops) { stop in NavigationLink { RecordDetailView(kind:"trips",id:stop.id) } label: { Text(stop.name); Text(recordDates(stop)).font(.caption).foregroundStyle(.secondary) } }
                            }
                        }
                        let allocations=data.trips.filter { $0.name == record.name && $0.start == record.start && $0.end == record.end && !record.start.isEmpty && !record.end.isEmpty }.sorted { $0.year < $1.year }
                        if Set(allocations.map(\.year)).count > 1 {
                            Section("Across worksheet years") {
                                Text("Repeated costs count once in all-time totals.").font(.footnote).foregroundStyle(.secondary)
                                ForEach(allocations) { row in VStack(alignment:.leading,spacing:4) { Text(String(row.year)).font(.headline); Text("Total \(pounds(row.number("total"))) · Days \(row.number("days").map { String(format:"%g",$0) } ?? "—") · Leave \(row.number("leave").map { String(format:"%g",$0) } ?? "—")").font(.caption).foregroundStyle(.secondary) } }
                            }
                        }
                        let events=data.events(during:record)
                        if !events.isEmpty { Section("Events during these dates") { ForEach(events) { event in NavigationLink { RecordDetailView(kind:"events",id:event.id) } label: { VStack(alignment:.leading) { Text(event.name); Text(recordDates(event)).font(.caption).foregroundStyle(.secondary) } } } } }
                        if record.bool("review") { Section { Label("Needs review",systemImage:"exclamationmark.circle").foregroundStyle(.orange) } }
                    } else if !record.start.isEmpty {
                        let trips=data.trips(on:record.start)
                        if !trips.isEmpty { Section("Trips on this day") { ForEach(trips) { trip in NavigationLink { RecordDetailView(kind:"trips",id:trip.id) } label: { TripRow(trip:trip,data:data) } } } }
                    }
                    Section("Notes") { Text(record.text("notes").isEmpty ? "No notes recorded." : record.text("notes")) }
                    if let failure { Section { Text(failure).foregroundStyle(.red) } }
                    Section { Button("Delete \(kind == "trips" ? "trip" : "event")",role:.destructive) { confirmDelete=true }.disabled(deleting) }
                }
                .scrollContentBackground(.hidden)
                .background(Color.atlasBackground.ignoresSafeArea())
                .navigationTitle(record.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.primaryAction) { Button("Edit") { editing=true } } }
                .sheet(isPresented:$editing) { NavigationStack { RecordEditorView(kind:kind,record:record,initialDate:nil) } }
                .confirmationDialog("Delete this entry?",isPresented:$confirmDelete,titleVisibility:.visible) {
                    Button("Delete",role:.destructive) { Task { await remove() } }
                    Button("Cancel",role:.cancel) {}
                } message: { Text("The server keeps the previous version in its history.") }
            } else { Text("This entry is no longer available.").foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private func valueRow(_ label:String,_ record:Record,_ key:String,money:Bool,data:AtlasData) -> some View {
        let shared=AtlasCalculations.isShared(record,key:key,trips:data.trips)
        let value=shared ? "Shared across journey" : (money ? pounds(record.number(key)) : record.number(key).map { String(format:"%g",$0) } ?? "—")
        LabeledContent(label,value:value)
    }
    private func remove() async { deleting=true; do { try await store.delete(kind:kind,id:id); dismiss() } catch { failure=error.localizedDescription }; deleting=false }
}
