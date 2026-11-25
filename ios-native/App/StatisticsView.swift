import SwiftUI
import Charts

struct StatisticsView: View {
    let data: AtlasData
    @State private var year: Int?
    @State private var month: Int?
    @State private var metric = "Spend"
    @State private var editingAnnual = false
    private var years:[Int] { Array(Set(data.trips.map(\.year).filter { $0 > 0 })).sorted(by:>) }
    private var summary:Summary { AtlasCalculations.summary(data.trips,year:year,month:month) }
    private var buckets:[Int] { year == nil ? years.sorted() : (month.map { [$0] } ?? Array(1...12)) }
    private func value(_ bucket:Int) -> Double {
        let rows=AtlasCalculations.scoped(data.trips,year:year,month:month)
        if year == nil {
            let selected=rows.filter { $0.year == bucket }
            if metric == "Days" { return Double(AtlasCalculations.days(rows,year:bucket,month:month)) }
            return AtlasCalculations.sum(selected,metric == "Spend" ? "total" : metric == "Flights" ? "flights" : "leave")
        }
        let selected=rows.filter { AtlasCalculations.allocationMonth($0) == bucket }
        if metric == "Days" { return Double(AtlasCalculations.days(rows,year:year,month:bucket)) }
        return AtlasCalculations.sum(selected,metric == "Spend" ? "total" : metric == "Flights" ? "flights" : "leave")
    }
    private func label(_ bucket:Int) -> String { year == nil ? String(bucket) : Calendar.current.shortMonthSymbols[bucket-1] }
    var body: some View {
        List {
            Section {
                HStack {
                    Menu { Picker("Year",selection:$year) { Text("All years").tag(Int?.none); ForEach(years,id:\.self) { Text(String($0)).tag(Optional($0)) } } } label: { Label(year.map(String.init) ?? "All years",systemImage:"calendar") }
                    Spacer()
                    Menu { Picker("Month",selection:$month) { Text("All months").tag(Int?.none); ForEach(1...12,id:\.self) { Text(Calendar.current.monthSymbols[$0-1]).tag(Optional($0)) } } } label: { Text(month.map { Calendar.current.monthSymbols[$0-1] } ?? "All months") }
                }
                .buttonStyle(.borderless)
            }
            Section("Your travel") {
                HStack { Metric(label:"Total spend",value:pounds(summary.total)); Spacer(); Metric(label:"Days away",value:String(summary.days)) }
                HStack { Metric(label:"Trip records",value:String(summary.records)); Spacer(); Metric(label:"Flights",value:String(format:"%g",summary.flights)); Spacer(); Metric(label:"Leave days",value:String(format:"%g",summary.leave)) }
            }
            Section("Highlights") {
                let today=localDateISO(Date())
                let dated=data.trips.filter { !$0.start.isEmpty }.sorted { $0.start < $1.start }
                let current=dated.first { $0.start <= today && !$0.end.isEmpty && $0.end >= today }
                let next=dated.first { $0.start > today }
                let latest=dated.last { $0.start <= today }
                if let current { NavigationLink { RecordDetailView(kind:"trips",id:current.id) } label: { LabeledContent("Current",value:current.name) } }
                if let next {
                    NavigationLink { RecordDetailView(kind:"trips",id:next.id) } label: { LabeledContent("Next",value:next.name) }
                    if let date=AtlasDates.parse(next.start), let todayDate=AtlasDates.parse(today) { Text("\(max(0,AtlasDates.utcCalendar.dateComponents([.day],from:todayDate,to:date).day ?? 0)) days to go").font(.footnote).foregroundStyle(.secondary) }
                }
                if let latest { NavigationLink { RecordDetailView(kind:"trips",id:latest.id) } label: { LabeledContent("Latest",value:latest.name) } }
                if current == nil && next == nil && latest == nil { Text("No dated trips yet.").foregroundStyle(.secondary) }
            }
            Section(year == nil ? "Yearly breakdown" : "Monthly breakdown") {
                Picker("Measure",selection:$metric) { ForEach(["Spend","Days","Flights","Leave"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
                Chart(buckets,id:\.self) { bucket in BarMark(x:.value("Period",label(bucket)),y:.value(metric,value(bucket))).foregroundStyle(Color.atlasAccent) }
                    .frame(height:180).accessibilityLabel("\(metric) by \(year == nil ? "year" : "month")")
                ForEach(buckets,id:\.self) { bucket in LabeledContent(label(bucket),value:metric == "Spend" ? pounds(value(bucket)) : String(format:"%g",value(bucket))) }
            }
            Section("Cost split") {
                if summary.travel + summary.accommodation > 0 {
                    ProgressView(value:summary.travel,total:summary.travel + summary.accommodation).tint(.atlasAccent)
                    Text("\(Int((summary.travel / (summary.travel + summary.accommodation) * 100).rounded()))% travel").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Travel",value:pounds(summary.travel))
                LabeledContent("Accommodation",value:pounds(summary.accommodation))
                Text("Component costs can differ from recorded totals.").font(.footnote).foregroundStyle(.secondary)
            }
            if let year, let values=data.summaries[String(year)]?.object {
                Section("Original worksheet figures") {
                    Text("These figures are preserved separately from live calculations.").font(.footnote).foregroundStyle(.secondary)
                    ForEach(AnnualEditorView.fields,id:\.key) { field in
                        LabeledContent(field.label,value:field.money ? pounds(values[field.key]?.number) : values[field.key]?.number.map { String(format:"%g",$0) } ?? "—")
                    }
                    if let note=values["notes"]?.string, !note.isEmpty { Text(note).font(.footnote).foregroundStyle(.secondary) }
                    Button("Edit annual figures") { editingAnnual=true }
                }
            }
            let reviewed=AtlasCalculations.scoped(data.trips,year:year,month:month).filter { $0.bool("review") }
            if !reviewed.isEmpty { Section("Needs review") { ForEach(reviewed) { trip in NavigationLink { RecordDetailView(kind:"trips",id:trip.id) } label: { TripRow(trip:trip,data:data) } } } }
        }
        .navigationTitle("Statistics")
        .onChange(of:year) { _ in month=nil }
        .sheet(isPresented:$editingAnnual) { if let year, let values=data.summaries[String(year)]?.object { NavigationStack { AnnualEditorView(year:year,values:values) } } }
    }
}
private struct Metric:View {
    let label:String; let value:String
    var body:some View { VStack(alignment:.leading,spacing:5) { Text(value).font(.title3.bold()).foregroundStyle(.tint).monospacedDigit(); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,4) }
}
struct AnnualField:Hashable { let key:String; let label:String; var money=false }
struct AnnualEditorView: View {
    @EnvironmentObject private var store:AtlasStore
    @Environment(\.dismiss) private var dismiss
    static let fields:[AnnualField] = [.init(key:"travel",label:"Travel (£)",money:true),.init(key:"accommodation",label:"Accommodation (£)",money:true),.init(key:"total",label:"Total (£)",money:true),.init(key:"days",label:"Days"),.init(key:"flights",label:"Flights"),.init(key:"percent",label:"Percent away"),.init(key:"leave_total",label:"Leave allowance"),.init(key:"other_usage",label:"Other leave usage"),.init(key:"leave_left",label:"Leave remaining"),.init(key:"bought",label:"Leave bought"),.init(key:"paid_back",label:"Paid back (£)",money:true)]
    let year:Int; let values:[String:JSONValue]
    @State private var draft:[String:String]
    @State private var failure:String?
    @State private var saving=false
    @State private var confirmDiscard=false
    init(year:Int,values:[String:JSONValue]) { self.year=year; self.values=values; _draft=State(initialValue:Dictionary(uniqueKeysWithValues:Self.fields.map { ($0.key,values[$0.key]?.number.map { String($0) } ?? "") })) }
    var body:some View {
        Form {
            Section { Text("These figures do not recalculate from trips.").font(.footnote).foregroundStyle(.secondary) }
            Section { ForEach(Self.fields,id:\.key) { field in TextField(field.label,text:Binding(get:{draft[field.key] ?? ""},set:{draft[field.key]=$0})).keyboardType(.decimalPad) } }
            if let failure { Text(failure).foregroundStyle(.red) }
            Section { Button(saving ? "Saving…" : "Save figures") { Task { await save() } }.disabled(saving) }
        }
        .navigationTitle("\(year) figures").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { confirmDiscard=true } } }
        .interactiveDismissDisabled()
        .confirmationDialog("Discard your changes?",isPresented:$confirmDiscard,titleVisibility:.visible) { Button("Discard changes",role:.destructive) { dismiss() }; Button("Keep editing",role:.cancel) {} }
    }
    private func save() async {
        var result=values
        for field in Self.fields {
            let text=(draft[field.key] ?? "").trimmingCharacters(in:.whitespaces)
            if text.isEmpty { result[field.key] = .null }
            else if let n=Double(text),n.isFinite { result[field.key] = .number(n) }
            else { failure="Enter a valid number for \(field.label)."; return }
        }
        saving=true; failure=nil
        do { _ = try await store.post("/api/summary",body:["year":.number(Double(year)),"values":.object(result)]); await store.load(); dismiss() } catch { failure=error.localizedDescription }
        saving=false
    }
}
