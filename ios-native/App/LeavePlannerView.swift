import SwiftUI

struct LeavePlannerView: View {
    @EnvironmentObject private var store: AtlasStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var mode = 0
    @State private var editingAllowance = false
    @State private var editingPlan: LeavePlan?
    @State private var failure: String?
    @State private var saving = false

    private var summary: [String:JSONValue] { store.data?.summaries[String(year)]?.object ?? [:] }
    private var settings: [String:JSONValue] { summary["leave_planner"]?.object ?? [:] }
    private var plans: [LeavePlan] { (settings["plans"]?.array ?? []).compactMap(LeavePlan.init) }
    private var allowance: Double { settings["allowance"]?.number ?? 0 }
    private var bought: Double { settings["bought"]?.number ?? 0 }
    private var other: Double { settings["other"]?.number ?? 0 }
    private var trips: [Record] { (store.data?.trips ?? []).filter { $0.year == year && ($0.number("leave") ?? 0) > 0 } }
    private var years: [Int] { LeaveYears.available(trips: store.data?.trips ?? [], summaries: store.data?.summaries ?? [:], current: Calendar.current.component(.year, from: Date())) }
    private var balance: LeaveBalance { LeaveBalance(trips: trips, year: year, today: localDateISO(Date()), allowance: allowance, bought: bought, other: other, plans: plans) }
    private func number(_ value: Double) -> String { String(format: "%g", value) }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Work days, not days away").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(years, id: \.self) { value in
                            Button(String(value)) { year = value }
                        }
                    } label: { Label(String(year), systemImage: "calendar") }.accessibilityIdentifier("leave-year")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available after booked leave").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(settings["allowance"] == nil ? "—" : number(balance.available)).font(.system(size: 48, weight: .semibold, design: .rounded)).monospacedDigit().accessibilityIdentifier("leave-available")
                        Text("days").foregroundStyle(.secondary)
                    }
                    Text("\(number(allowance)) allowance + \(number(bought)) bought").font(.footnote).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                if settings["allowance"] == nil { Text("Set your allowance to calculate your balance.").font(.footnote).foregroundStyle(.secondary) }
            }
            Section {
                Picker("Leave view", selection: $mode) { Text("Balance").tag(0); Text("Plan a trip").tag(1) }.pickerStyle(.segmented)
            }
            if mode == 0 {
                Section {
                    LabeledContent("Annual allowance", value: "\(number(allowance)) days")
                    LabeledContent("Extra days bought", value: "+ \(number(bought))")
                    LabeledContent("Leave taken", value: "− \(number(balance.taken))")
                    LabeledContent("Booked trips", value: "− \(number(balance.booked))")
                    LabeledContent("Other leave used", value: "− \(number(other))")
                    Button("Edit allowance") { editingAllowance = true }
                } header: { Text("Your balance") } footer: { Text("Trip leave comes from the recorded leave days on your trips. Undated trips count as taken. Enter other leave separately.") }
                if !trips.isEmpty {
                    Section("Trip leave") {
                        ForEach(trips.sorted { $0.start < $1.start }) { trip in
                            NavigationLink { RecordDetailView(kind: "trips", id: trip.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack { Text(trip.name); Spacer(); Text("\(number(trip.number("leave") ?? 0)) days").monospacedDigit() }
                                    Text(recordDates(trip)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                let bookedTrips = trips.filter { !$0.start.isEmpty && $0.start > localDateISO(Date()) }.sorted { $0.start < $1.start }
                if !bookedTrips.isEmpty {
                    Section("Booked trips") {
                        ForEach(bookedTrips) { trip in
                            NavigationLink { RecordDetailView(kind: "trips", id: trip.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack { Text(trip.name); Spacer(); Text("− \(number(trip.number("leave") ?? 0)) days").monospacedDigit() }
                                    Text(recordDates(trip)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(plans) { plan in
                        HStack {
                            Button { editingPlan = plan } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.name).foregroundStyle(.primary)
                                    Text("\(AtlasDates.display(plan.start)) – \(AtlasDates.display(plan.end)) · \(number(plan.days)) days").font(.caption).foregroundStyle(.secondary)
                                    Text("POSSIBLE TRIP").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Toggle("Include \(plan.name) in projection", isOn: Binding(get: { plan.included }, set: { value in
                                var updated = plans
                                if let index = updated.firstIndex(where: { $0.id == plan.id }) { updated[index].included = value; Task { await savePlans(updated) } }
                            })).labelsHidden().accessibilityIdentifier("include-leave-plan-\(plan.name)").disabled(saving)
                        }
                    }
                    .onDelete { offsets in var updated = plans; updated.remove(atOffsets: offsets); Task { await savePlans(updated) } }
                    Button { editingPlan = LeavePlan(id: UUID().uuidString, name: "", start: "", end: "", days: 0, included: true) } label: { Label("Add idea", systemImage: "plus") }
                } header: { Text("Try your plans") } footer: { Text("Tap an idea to edit it or swipe to delete. Enter work days yourself, including half days; bank holidays are not calculated automatically.") }
                Section("If you take these ideas") {
                    LabeledContent("Projected remaining") { Text(settings["allowance"] == nil ? "Set allowance first" : "\(number(balance.projected)) days").accessibilityIdentifier("leave-projected") }
                    Text("Possible trips do not change your actual balance.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let failure { Section { Text(failure).foregroundStyle(.red); Button("Dismiss") { self.failure = nil } } }
        }
        .scrollContentBackground(.hidden).background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Annual leave")
        .onAppear { if !years.contains(year), let first = years.first { year = first } }
        .sheet(isPresented: $editingAllowance) { NavigationStack { LeaveAllowanceEditor(year: year, settings: settings) { value in await saveSettings(value) } } }
        .sheet(item: $editingPlan) { plan in NavigationStack { LeavePlanEditor(year: year, plan: plan) { value in
            var updated = plans
            if let index = updated.firstIndex(where: { $0.id == value.id }) { updated[index] = value } else { updated.append(value) }
            return await savePlans(updated)
        } } }
    }
    private func savePlans(_ updated: [LeavePlan]) async -> Bool {
        var value = settings; value["plans"] = .array(updated.map(\.json)); return await saveSettings(value)
    }
    private func saveSettings(_ value: [String:JSONValue]) async -> Bool {
        guard !saving else { return false }
        let savedYear = year
        saving = true; failure = nil
        defer { saving = false }
        do {
            let latest = try await store.fetch("/api/data")
            var values = latest.object?["summaries"]?.object?[String(savedYear)]?.object ?? [:]
            values["leave_planner"] = .object(value)
            _ = try await store.post("/api/summary", body: ["year":.number(Double(savedYear)), "values":.object(values)])
            store.applySummary(year: savedYear, values: values)
            return true
        } catch { failure = error.localizedDescription; return false }
    }
}

struct LeaveAllowanceEditor: View {
    @Environment(\.dismiss) private var dismiss
    let year: Int
    let settings: [String:JSONValue]
    let save: ([String:JSONValue]) async -> Bool
    @State private var allowance: String
    @State private var bought: String
    @State private var other: String
    @State private var error: String?
    @State private var saving = false
    init(year: Int, settings: [String:JSONValue], save: @escaping ([String:JSONValue]) async -> Bool) {
        self.year = year; self.settings = settings; self.save = save
        _allowance = State(initialValue: settings["allowance"]?.number.map { String(format:"%g", $0) } ?? "")
        _bought = State(initialValue: String(format:"%g", settings["bought"]?.number ?? 0))
        _other = State(initialValue: String(format:"%g", settings["other"]?.number ?? 0))
    }
    var body: some View {
        Form {
            Section("Work days for \(year)") {
                LabeledContent("Annual allowance") { TextField("Days", text: $allowance).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Extra days bought") { TextField("Days", text: $bought).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Other leave used") { TextField("Days", text: $other).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }.modifier(KeyboardDismissToolbar()).navigationTitle("Leave allowance").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await submit() } }.disabled(saving) }
            }.interactiveDismissDisabled(saving)
    }
    private func submit() async {
        guard let a = Double(allowance), let b = Double(bought), let o = Double(other), [a,b,o].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 366 }) else { error = "Enter valid days between 0 and 366."; return }
        var value = settings; value["allowance"] = .number(a); value["bought"] = .number(b); value["other"] = .number(o)
        saving = true
        if await save(value) { dismiss() } else { error = "Could not save. Check your connection and try again." }
        saving = false
    }
}

struct LeavePlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    let year: Int
    let plan: LeavePlan
    let save: (LeavePlan) async -> Bool
    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    @State private var days: String
    @State private var error: String?
    @State private var saving = false
    init(year: Int, plan: LeavePlan, save: @escaping (LeavePlan) async -> Bool) {
        self.year = year; self.plan = plan; self.save = save
        let initial = localDate(fromISO: "\(year)-01-01") ?? Date()
        _name = State(initialValue: plan.name); _start = State(initialValue: localDate(fromISO: plan.start) ?? initial); _end = State(initialValue: localDate(fromISO: plan.end) ?? initial)
        _days = State(initialValue: plan.name.isEmpty ? "" : String(format:"%g", plan.days))
    }
    var body: some View {
        Form {
            Section {
                TextField("Trip name", text: $name)
                DatePicker("Start date", selection: $start, displayedComponents: .date)
                DatePicker("End date", selection: $end, displayedComponents: .date)
                LabeledContent("Work days needed") { TextField("Days", text: $days).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            } footer: { Text("Enter the work days yourself, including any half days.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.modifier(KeyboardDismissToolbar()).navigationTitle(plan.name.isEmpty ? "Add idea" : "Edit idea").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await submit() } }.disabled(saving) }
            }.interactiveDismissDisabled(saving)
    }
    private func submit() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { error = "Enter a trip name (up to 200 characters)."; return }
        guard let count = Double(days), count.isFinite, count >= 0, count <= 366 else { error = "Enter valid work days between 0 and 366."; return }
        let first = localDateISO(start), last = localDateISO(end)
        guard first <= last, first.hasPrefix("\(year)-"), last.hasPrefix("\(year)-") else { error = "Choose dates in \(year), with the end on or after the start."; return }
        saving = true
        if await save(LeavePlan(id: plan.id, name: trimmed, start: first, end: last, days: count, included: plan.included)) { dismiss() }
        else { error = "Could not save. Check your connection and try again." }
        saving = false
    }
}
