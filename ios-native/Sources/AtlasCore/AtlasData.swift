import Foundation

public enum JSONValue: Codable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
    public var string: String? { if case .string(let value) = self { return value }; return nil }
    public var number: Double? { if case .number(let value) = self { return value }; return nil }
    public var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
    public var object: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    public var array: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
}

public struct Record: Identifiable {
    public var fields: [String: JSONValue]
    public init(_ fields: [String: JSONValue]) { self.fields = fields }
    public var id: Int { Int(number("id") ?? 0) }
    public var name: String { text("name") }
    public var start: String { text("start") }
    public var end: String { text("end") }
    public var year: Int { Int(number("year") ?? 0) }
    public func text(_ key: String) -> String { fields[key]?.string ?? "" }
    public func number(_ key: String) -> Double? { fields[key]?.number }
    public func bool(_ key: String) -> Bool { fields[key]?.bool ?? false }
}

public struct AtlasData {
    public var trips: [Record]
    public var events: [Record]
    public var places: [String: JSONValue]
    public var summaries: [String: JSONValue]
    public var overrides: [[JSONValue]]
    public init(json: [String: JSONValue]) {
        trips = (json["trips"]?.array ?? []).compactMap { $0.object.map(Record.init) }
        events = (json["events"]?.array ?? []).compactMap { $0.object.map(Record.init) }
        places = json["places"]?.object ?? [:]
        summaries = json["summaries"]?.object ?? [:]
        overrides = (json["calendar-overrides"]?.array ?? []).compactMap(\.array)
    }
    public func place(for trip: Record) -> [String: JSONValue] {
        var place = places[trip.name]?.object ?? [:]
        for key in ["country", "lat", "lon", "pins"] {
            if let value = trip.fields[key] { place[key] = value }
        }
        return place
    }
    public func countries(for trip: Record) -> [String] {
        (place(for: trip)["country"]?.string ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    public func calendarRange(for trip: Record) -> (String, String) {
        if trip.bool("calendar_confirmed") { return (trip.start, trip.end) }
        for row in overrides where row.count >= 5 {
            if Int(row[0].number ?? 0) == trip.year && row[1].string == trip.name && row[2].string == trip.start {
                return (row[3].string ?? trip.start, row[4].string ?? trip.end)
            }
        }
        return (trip.start, trip.end)
    }
    public func trips(on day: String) -> [Record] {
        var seen = Set<String>()
        return trips.filter { trip in
            let (start, end) = calendarRange(for: trip)
            let key = "\(trip.name)|\(trip.start)|\(trip.end)"
            guard !start.isEmpty, !end.isEmpty, start <= day, day <= end, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
    public func events(on day: String) -> [Record] {
        events.filter { !$0.start.isEmpty && !$0.end.isEmpty && $0.start <= day && day <= $0.end }
    }
    public func events(during trip: Record) -> [Record] {
        let (start, end) = calendarRange(for: trip)
        guard !start.isEmpty, !end.isEmpty, start <= end else { return [] }
        return events.filter { !$0.start.isEmpty && !$0.end.isEmpty && $0.start <= end && $0.end >= start }
            .sorted { $0.start == $1.start ? $0.name < $1.name : $0.start < $1.start }
    }
}

public enum AtlasDates {
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }
    public static func parse(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents(); components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        guard let date = utcCalendar.date(from: components) else { return nil }
        return iso(date) == value ? date : nil
    }
    public static func iso(_ date: Date) -> String {
        let parts = utcCalendar.dateComponents([.year,.month,.day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    public static func display(_ value: String) -> String {
        guard let date = parse(value) else { return "Undated" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_GB"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

public enum AtlasCalculations {
    public static func allocationMonth(_ trip: Record) -> Int {
        guard trip.start.count >= 7 else { return 0 }
        return String(trip.start.prefix(4)) == String(trip.year) ? Int(trip.start.dropFirst(5).prefix(2)) ?? 0 : 1
    }
    public static func uniqueCosts(_ rows: [Record]) -> [Record] {
        var seen = Set<[JSONValueKey]>()
        return rows.filter { trip in
            let key = ["name","start","end","travel","accommodation","total"].map { JSONValueKey(trip.fields[$0] ?? .null) }
            return seen.insert(key).inserted
        }
    }
    private struct JSONValueKey: Hashable {
        let value: String
        init(_ json: JSONValue) {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            value = (try? encoder.encode(json)).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        }
    }
    public static func uniqueVisits(_ rows: [Record]) -> [Record] {
        var seen = Set<String>()
        return rows.filter { seen.insert("\($0.name)|\($0.start)|\($0.end)").inserted }
    }
    public static func collapseYearDuplicates(_ rows: [Record]) -> [Record] {
        var seen: [String: Set<Int>] = [:]
        return rows.filter { trip in
            guard !trip.start.isEmpty, !trip.end.isEmpty else { return true }
            let key = "\(trip.name)|\(trip.start)|\(trip.end)"
            if seen[key] == nil { seen[key] = [trip.year]; return true }
            if seen[key]?.contains(trip.year) == false { seen[key]?.insert(trip.year); return false }
            return true
        }
    }
    public static func sum(_ rows: [Record], _ key: String) -> Double { rows.reduce(0) { $0 + ($1.number(key) ?? 0) } }
    public static func scoped(_ rows: [Record], year: Int?, month: Int? = nil) -> [Record] {
        rows.filter { trip in
            if let year, trip.year != year { return false }
            guard let month else { return true }
            if allocationMonth(trip) == month { return true }
            guard !trip.start.isEmpty, !trip.end.isEmpty else { return false }
            let y = year ?? trip.year
            guard let first = AtlasDates.parse(String(format: "%04d-%02d-01", y, month)),
                  let next = AtlasDates.utcCalendar.date(byAdding: .month, value: 1, to: first),
                  let last = AtlasDates.utcCalendar.date(byAdding: .day, value: -1, to: next) else { return false }
            return trip.start <= AtlasDates.iso(last) && trip.end >= AtlasDates.iso(first)
        }
    }
    public static func days(_ rows: [Record], year: Int? = nil, month: Int? = nil) -> Int {
        var dates = Set<String>()
        for trip in rows {
            guard var day = AtlasDates.parse(trip.start), let end = AtlasDates.parse(trip.end), day <= end,
                  end.timeIntervalSince(day) <= 1000 * 86400 else { continue }
            while day <= end {
                let parts = AtlasDates.utcCalendar.dateComponents([.year,.month], from: day)
                if (year == nil || parts.year == year) && (month == nil || parts.month == month) { dates.insert(AtlasDates.iso(day)) }
                guard let next = AtlasDates.utcCalendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return dates.count
    }
    public static func summary(_ all: [Record], year: Int?, month: Int? = nil) -> Summary {
        let rows = scoped(all, year: year, month: month)
        let allocated = month == nil ? rows : rows.filter { allocationMonth($0) == month }
        let costs = year == nil ? uniqueCosts(allocated) : allocated
        return Summary(records: rows.count, total: sum(costs,"total"), travel: sum(costs,"travel"), accommodation: sum(costs,"accommodation"), days: days(rows,year:year,month:month), flights: sum(allocated,"flights"), leave: sum(allocated,"leave"))
    }
    public static func isShared(_ trip: Record, key: String, trips: [Record]) -> Bool {
        let groups: [String: [String]] = ["2022-americas":["travel","total","flights","days"], "2023-alps":["travel","accommodation","total","days"], "2023-world":["travel","total","days"], "2023-paris":["travel","total","leave"], "2024-summer":["days","leave"], "2024-autumn":["days"], "2025-easter":["days"], "2025-americas":["flights","days","leave"], "2025-newyear":["days","leave"], "2026-asia":["travel","total","flights","days","leave"]]
        let group = trip.text("group")
        guard !group.isEmpty else { return false }
        if groups[group]?.contains(key) == true { return true }
        guard ["travel","flights","days","leave"].contains(key) else { return false }
        let own = trip.fields["shared_fields"]?.array?.compactMap(\.string) ?? []
        if own.contains(key) { return true }
        return trip.number(key) == nil && trips.contains { $0.text("group") == group && ($0.fields["shared_fields"]?.array?.compactMap(\.string).contains(key) ?? false) }
    }
}
public struct Summary {
    public let records: Int
    public let total, travel, accommodation: Double
    public let days: Int
    public let flights, leave: Double
}
