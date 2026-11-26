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
    func testMonthlyAllocationsAndNullCosts() {
        let first = Record(["id":.number(1),"name":.string("Cross-year"),"year":.number(2026),"start":.string("2025-12-30"),"end":.string("2026-01-02"),"total":.number(100),"travel":.null])
        let second = Record(["id":.number(2),"name":.string("Summer"),"year":.number(2026),"start":.string("2026-06-28"),"end":.string("2026-07-03"),"total":.number(200),"travel":.number(75)])
        XCTAssertEqual(AtlasCalculations.allocationMonth(first),1)
        XCTAssertEqual(AtlasCalculations.summary([first,second],year:2026,month:1).total,100)
        XCTAssertEqual(AtlasCalculations.summary([first,second],year:2026,month:7).total,0)
        XCTAssertEqual(AtlasCalculations.summary([first,second],year:2026,month:7).days,3)
    }
    func testExistingPinsAndConfirmedCalendarDates() {
        let trip = Record(["id":.number(1),"name":.string("A"),"year":.number(2026),"start":.string("2026-01-02"),"end":.string("2026-01-04"),"calendar_confirmed":.bool(true),"pins":.array([])])
        let data = AtlasData(json:["trips":.array([.object(trip.fields)]),"places":.object(["A":.object(["country":.string("Japan"),"lat":.number(1),"lon":.number(2)])]),"calendar-overrides":.array([.array([.number(2026),.string("A"),.string("2026-01-02"),.string("2026-01-03"),.string("2026-01-05")])])])
        XCTAssertEqual(data.countries(for:trip),["Japan"])
        XCTAssertEqual(data.place(for:trip)["pins"],.array([]))
        XCTAssertEqual(data.trips(on:"2026-01-02").count,1)
    }
    func testSharedFieldsAndUnknownDates() {
        let owner=Record(["group":.string("journey-one"),"shared_fields":.array([.string("travel")]),"travel":.number(20)])
        let other=Record(["group":.string("journey-one"),"travel":.null])
        XCTAssertTrue(AtlasCalculations.isShared(other,key:"travel",trips:[owner,other]))
        XCTAssertFalse(AtlasCalculations.isShared(other,key:"total",trips:[owner,other]))
        XCTAssertEqual(AtlasCalculations.days([Record(["start":.string(""),"end":.string("")])]),0)
    }

    func testAllYearsKeepsSameYearDuplicatesButHidesCrossYearAllocation() {
        let rows = [trip(1,2025,"A","2025-12-30","2026-01-02",total:30), trip(2,2025,"A","2025-12-30","2026-01-02",total:30), trip(3,2026,"A","2025-12-30","2026-01-02",total:30)]
        XCTAssertEqual(AtlasCalculations.collapseYearDuplicates(rows).map(\.id),[1,2])
    }

    func testLeaveProjectionSeparatesBookedTakenAndIdeas() {
        let taken = Record(["year":.number(2027), "start":.string("2027-02-01"), "leave":.number(2.5)])
        let booked = Record(["year":.number(2027), "start":.string("2027-09-01"), "leave":.number(4)])
        let otherYear = Record(["year":.number(2028), "start":.string("2028-01-01"), "leave":.number(10)])
        let included = LeavePlan(id:"a", name:"Idea", start:"2027-10-01", end:"2027-10-03", days:1.5, included:true)
        let excluded = LeavePlan(id:"b", name:"Other", start:"2027-11-01", end:"2027-11-03", days:3, included:false)
        let result = LeaveBalance(trips:[taken,booked,otherYear], year:2027, today:"2027-06-01", allowance:25, bought:2, other:1, plans:[included,excluded])
        XCTAssertEqual(result.taken,2.5)
        XCTAssertEqual(result.booked,4)
        XCTAssertEqual(result.available,19.5)
        XCTAssertEqual(result.projected,18)
        XCTAssertEqual(LeavePlan(included.json), included)
    }

    func testLeaveYearsUseOnlyRecordedYears() {
        let trips = [Record(["year":.number(2020)]), Record(["year":.number(2027)]), Record(["year":.number(2020)]), Record([:])]
        XCTAssertEqual(LeaveYears.available(trips:trips, summaries:["2024":.object([:]), "invalid":.object([:])], current:2026), [2027,2024,2020])
        XCTAssertEqual(LeaveYears.available(trips:[], summaries:[:], current:2026), [2026])
    }

}
