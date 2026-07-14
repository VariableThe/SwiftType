import XCTest
@testable import SwiftTypeSystem

final class AccessibilityCoordinatorTests: XCTestCase {
    func testCoordinatorInitialization() {
        let coordinator = AccessibilityCoordinator.shared
        XCTAssertNotNil(coordinator)
        
        // Note: In an unprivileged test runner environment, isTrusted will be false unless granted.
        // We verify that calling isTrusted does not crash or throw.
        _ = coordinator.isTrusted
    }
}
