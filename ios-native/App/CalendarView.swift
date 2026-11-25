import SwiftUI

struct CalendarView:View {
    let data:AtlasData
    @State private var cursor=Date()
    @State private var selected=Date()
    @State private var mode="Month"
    @State private var query=""
    @State private var adding=false
    private var calendar:Calendar { var c=Calendar(identifier:.gregorian); c.locale=Locale(identifier:"en_GB"); c.firstWeekday=2; return c }
    private var monthTitle:String { cursor.formatted(.dateTime.month(.wide).year().locale(Locale(identifier:"en_GB"))) }
    private var y:Int { calendar.component(.year,from:cursor) }
    private var m:Int { calendar.component(.month,from:cursor) }
    private var startOfMonth:Date { calendar.date(from:DateComponents(year:y,month:m,day:1)) ?? cursor }
    private var days:Int { calendar.range(of:.day,in:.month,for:startOfMonth)?.count ?? 30 }
    private var offset:Int { (calendar.component(.weekday,from:startOfMonth)+5)%7 }
    private var results:[(String,Record)] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return (data.events.map { ("events",$0) } + AtlasCalculations.uniqueVisits(data.trips).map { ("trips",$0) }).filter { "\($0.1.name) \($0.1.text("notes"))".localizedCaseInsensitiveContains(q) }.sorted { $0.1.start > $1.1.start }
    }
    private func day(_ number:Int) -> Date { calendar.date(from:DateComponents(year:y,month:m,day:number)) ?? startOfMonth }
    var body:some View {
        List {
            if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                Section("Search results") {
                    if results.isEmpty { Text("No matching entries found.").foregroundStyle(.secondary) }
                    ForEach(Array(results.enumerated()),id:\.offset) { _, item in entry(kind:item.0,record:item.1) }
                }
            } else {
                Section {
                    Picker("View",selection:$mode) { ForEach(["Month","Agenda","Year"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
                    HStack {
                        Button { move(-1) } label: { Image(systemName:"chevron.left") }.accessibilityLabel("Previous \(mode == "Year" ? "year" : "month")")
                        Spacer(); Text(mode == "Year" ? String(y) : monthTitle).font(.headline); Spacer()
                        Button { move(1) } label: { Image(systemName:"chevron.right") }.accessibilityLabel("Next \(mode == "Year" ? "year" : "month")")
                    }.buttonStyle(.borderless).padding(.vertical,4)
                    Button("Today") { cursor=Date(); selected=Date() }
                }
                if mode == "Month" {
                    Section {
                        let columns=Array(repeating:GridItem(.flexible(),spacing:1),count:7)
                        LazyVGrid(columns:columns,spacing:6) {
                            ForEach(Array(["M","T","W","T","F","S","S"].enumerated()),id:\.offset) { _, label in Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth:.infinity) }
                            ForEach(0..<offset,id:\.self) { _ in Color.clear.frame(height:42) }
                            ForEach(1...days,id:\.self) { number in
                                let date=day(number), value=localDateISO(date), hasEntries = !data.trips(on:value).isEmpty || !data.events(on:value).isEmpty, isSelected=calendar.isDate(date,inSameDayAs:selected)
                                Button { selected=date } label: {
                                    VStack(spacing:2) { Text(String(number)).font(.subheadline.weight(isSelected ? .bold : .regular)); Circle().fill(hasEntries ? (isSelected ? Color.black : .atlasAccent) : .clear).frame(width:4,height:4) }
                                        .frame(maxWidth:.infinity,minHeight:42).background(isSelected ? Color.atlasAccent : .clear,in:RoundedRectangle(cornerRadius:9)).foregroundStyle(isSelected ? Color.black : .primary)
                                }.buttonStyle(.plain).accessibilityLabel("\(AtlasDates.display(value)), \(hasEntries ? "has entries" : "no entries")")
                            }
                        }
                    }
                    Section(AtlasDates.display(localDateISO(selected))) {
                        let date=localDateISO(selected), trips=data.trips(on:date), events=data.events(on:date)
                        if trips.isEmpty && events.isEmpty { Text("Nothing recorded on this day.").foregroundStyle(.secondary) }
                        ForEach(trips) { entry(kind:"trips",record:$0) }
                        ForEach(events) { entry(kind:"events",record:$0) }
                        Button { adding=true } label: { Label("Add event on this day",systemImage:"plus") }
                    }
                } else if mode == "Agenda" {
                    ForEach(1...days,id:\.self) { number in
                        let date=localDateISO(day(number)), trips=data.trips(on:date), events=data.events(on:date)
                        if !trips.isEmpty || !events.isEmpty { Section(AtlasDates.display(date)) { ForEach(trips) { entry(kind:"trips",record:$0) }; ForEach(events) { entry(kind:"events",record:$0) } } }
                    }
                } else {
                    ForEach(1...12,id:\.self) { number in
                        let first=calendar.date(from:DateComponents(year:y,month:number,day:1)) ?? cursor
                        let start=localDateISO(first), next=calendar.date(byAdding:.month,value:1,to:first) ?? first, end=localDateISO(calendar.date(byAdding:.day,value:-1,to:next) ?? first)
                        let count=data.events.filter { !$0.start.isEmpty && !$0.end.isEmpty && $0.start <= end && $0.end >= start }.count
                        let trips=data.trips.filter { let (a,b)=data.calendarRange(for:$0); return !a.isEmpty && !b.isEmpty && a <= end && b >= start }.count
                        Button { cursor=first; selected=first; mode="Month" } label: { HStack { VStack(alignment:.leading) { Text(first.formatted(.dateTime.month(.wide).locale(Locale(identifier:"en_GB")))); Text("\(count) events · \(trips) trip records").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary) } }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Calendar").modifier(KeyboardDismissToolbar()).onSubmit(of:.search) { dismissAtlasKeyboard() }.searchable(text:$query,prompt:"Search events and trips")
        .toolbar { ToolbarItem(placement:.primaryAction) { Button { adding=true } label: { Image(systemName:"plus") }.accessibilityLabel("Add event") } }
        .sheet(isPresented:$adding) { NavigationStack { RecordEditorView(kind:"events",record:nil,initialDate:selected) } }
    }
    @ViewBuilder private func entry(kind:String,record:Record) -> some View {
        NavigationLink { RecordDetailView(kind:kind,id:record.id) } label: { VStack(alignment:.leading,spacing:3) { Text(record.name); Text("\(kind == "trips" ? "Trip" : record.text("kind") == "context" ? "Calendar context" : "Personal event") · \(recordDates(record))").font(.caption).foregroundStyle(.secondary) } }
    }
    private func move(_ amount:Int) { let component:Calendar.Component = mode == "Year" ? .year : .month; if let next=calendar.date(byAdding:component,value:amount,to:startOfMonth) { cursor=next; selected=next } }
}
