import Foundation

public enum LeaveYears {
    public static func available(trips: [Record], summaries: [String: JSONValue], current: Int) -> [Int] {
        let tripYears = trips.map(\.year).filter { (1900...2200).contains($0) }
        let summaryYears = summaries.keys.compactMap(Int.init).filter { (1900...2200).contains($0) }
        let years = Set(tripYears + summaryYears)
        return years.isEmpty ? [current] : years.sorted(by: >)
    }
}

public enum LeaveSettings {
    public static func resolved(_ summary: [String: JSONValue]) -> [String: JSONValue] {
        var result = summary["leave_planner"]?.object ?? [:]
        let bought = summary["bought"]?.number ?? 0
        if result["allowance"] == nil, let total = summary["leave_total"]?.number,
           total.isFinite, bought.isFinite, total >= bought, bought >= 0 {
            result["allowance"] = .number(total - bought)
            if result["bought"] == nil { result["bought"] = .number(bought) }
        }
        if result["other"] == nil, let other = summary["other_usage"]?.number, other.isFinite, other >= 0 {
            result["other"] = .number(other)
        }
        return result
    }
}

public struct LeavePlan: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var start: String
    public var end: String
    public var days: Double
    public var included: Bool

    public init(id: String, name: String, start: String, end: String, days: Double, included: Bool) {
        self.id = id; self.name = name; self.start = start; self.end = end; self.days = days; self.included = included
    }
    public init?(_ value: JSONValue) {
        guard let object = value.object, let id = object["id"]?.string, let name = object["name"]?.string,
              let start = object["start"]?.string, let end = object["end"]?.string, let days = object["days"]?.number else { return nil }
        self.init(id: id, name: name, start: start, end: end, days: days, included: object["included"]?.bool ?? true)
    }
    public var json: JSONValue {
        .object(["id":.string(id), "name":.string(name), "start":.string(start), "end":.string(end), "days":.number(days), "included":.bool(included)])
    }
}

public struct LeaveBalance {
    public let taken: Double
    public let booked: Double
    public let available: Double
    public let projected: Double
    public init(trips: [Record], year: Int, today: String, allowance: Double, bought: Double, other: Double, plans: [LeavePlan]) {
        let rows = trips.filter { $0.year == year }
        booked = rows.filter { !$0.start.isEmpty && $0.start > today }.reduce(0) { $0 + ($1.number("leave") ?? 0) }
        taken = rows.filter { $0.start.isEmpty || $0.start <= today }.reduce(0) { $0 + ($1.number("leave") ?? 0) }
        available = allowance + bought - other - taken - booked
        projected = available - plans.filter(\.included).reduce(0) { $0 + $1.days }
    }
}
