import XCTest
@testable import AtlasCore

final class AtlasCoreTests: XCTestCase {
    private func trip(_ id: Int, _ year: Int, _ name: String, _ start: String, _ end: String, total: Double) -> Record {
        Record(["id":.number(Double(id)), "year":.number(Double(year)), "name":.string(name), "start":.string(start), "end":.string(end), "travel":.number(10), "accommodation":.number(20), "total":.number(total)])
    }
    func testAllTimeDeduplicatesCostAndOverlappingDays() {
        let rows = [trip(1,2025,"A","2025-12-30","2026-01-02",total:30), trip(2,2026,"A","2025-12-30","2026-01-02",total:30), trip(3,2026,"B","2026-01-02","2026-01-03",total:5)]
        let summary = AtlasCalculations.summary(rows, year:nil)
        XCTAssertEqual(summary.total, 35)
        XCTAssertEqual(summary.days, 5)
        XCTAssertEqual(AtlasCalculations.summary(rows,year:2026,month:1).total, 35)
        XCTAssertEqual(AtlasCalculations.summary(rows,year:2026).days, 3)
    }
    func testCalendarOverrideAndEvents() {
        let json: [String:JSONValue] = ["trips":.array([.object(trip(1,2026,"A","2026-01-02","2026-01-04",total:5).fields)]), "events":.array([.object(["id":.number(2),"name":.string("Concert"),"start":.string("2026-01-03"),"end":.string("2026-01-03")])]), "calendar-overrides":.array([.array([.number(2026),.string("A"),.string("2026-01-02"),.string("2026-01-03"),.string("2026-01-05")])])]
        let data = AtlasData(json:json)
        XCTAssertEqual(data.trips(on:"2026-01-02").count,0)
        XCTAssertEqual(data.trips(on:"2026-01-03").count,1)
        XCTAssertEqual(data.events(during:data.trips[0]).first?.name,"Concert")
    }
    func testUnknownRecordFieldsSurviveEncoding() throws {
        let value = JSONValue.object(["name":.string("Trip"),"notes":.string("keep"),"pins":.array([.object(["name":.string("Place"),"lat":.number(10)])])])
        let bytes = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self,from:bytes),value)
    }
    func testDateValidationAndSharedCosts() {
        XCTAssertNil(AtlasDates.parse("2026-02-30"))
        XCTAssertNotNil(AtlasDates.parse("2024-02-29"))
        let trip = Record(["group":.string("2023-world")])
        XCTAssertTrue(AtlasCalculations.isShared(trip,key:"total",trips:[]))
    }
}
