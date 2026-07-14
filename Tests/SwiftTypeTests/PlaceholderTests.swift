import XCTest
@testable import SwiftTypeCore
@testable import SwiftTypeSystem
@testable import SwiftTypeUI

final class PlaceholderTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertEqual(SystemPlaceholder.version, "1.0.0")
    }
}
