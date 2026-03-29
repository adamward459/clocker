import XCTest
@testable import Clocker

final class DurationFormatterTests: XCTestCase {
    func testFormatsBoundaryValues() {
        XCTAssertEqual(DurationFormatter.string(from: 9), "00:00:09")
        XCTAssertEqual(DurationFormatter.string(from: 59), "00:00:59")
        XCTAssertEqual(DurationFormatter.string(from: 60), "00:01:00")
        XCTAssertEqual(DurationFormatter.string(from: 3599), "00:59:59")
        XCTAssertEqual(DurationFormatter.string(from: 3600), "01:00:00")
        XCTAssertEqual(DurationFormatter.string(from: 4830), "01:20:30")
    }
}
