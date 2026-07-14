import XCTest
@testable import SwiftTypeCore

final class KeyboardModelTests: XCTestCase {
    var model: KeyboardModel!

    override func setUp() {
        super.setUp()
        model = KeyboardModel(layout: .qwerty)
    }

    override func tearDown() {
        model = nil
        super.tearDown()
    }

    func testKeyDistanceQWERTY() {
        // r <-> e are adjacent
        let distRE = model.keyDistance(between: "r", and: "e")
        XCTAssertEqual(distRE, 1.0, accuracy: 0.01)

        // t <-> y are adjacent
        let distTY = model.keyDistance(between: "t", and: "y")
        XCTAssertEqual(distTY, 1.0, accuracy: 0.01)

        // q <-> p are far apart (distance ~9)
        let distQP = model.keyDistance(between: "q", and: "p")
        XCTAssertEqual(distQP, 9.0, accuracy: 0.01)
    }

    func testSubstitutionCost() {
        let costSame = model.substitutionCost(from: "a", to: "a")
        XCTAssertEqual(costSame, 0.0)

        let costAdjacent = model.substitutionCost(from: "r", to: "e")
        XCTAssertEqual(costAdjacent, 0.25)

        let costFar = model.substitutionCost(from: "q", to: "m")
        XCTAssertEqual(costFar, 1.0)
    }

    func testExemptionsAndWeightedEditCost() {
        // teh -> the should have extremely low cost
        let costTeh = model.weightedEditCost(source: "teh", target: "the")
        XCTAssertEqual(costTeh, 0.1, accuracy: 0.01)

        // becuase -> because
        let costBecuase = model.weightedEditCost(source: "becuase", target: "because")
        XCTAssertEqual(costBecuase, 0.1, accuracy: 0.01)

        // garabage -> garbage
        let costGarabage = model.weightedEditCost(source: "garabage", target: "garbage")
        XCTAssertEqual(costGarabage, 0.1, accuracy: 0.01)

        // reccomend -> recommend
        let costReccomend = model.weightedEditCost(source: "reccomend", target: "recommend")
        XCTAssertEqual(costReccomend, 0.1, accuracy: 0.01)
    }

    func testAlternativeLayouts() {
        let dvorak = KeyboardModel(layout: .dvorak)
        let colemak = KeyboardModel(layout: .colemak)

        XCTAssertGreaterThanOrEqual(dvorak.keyDistance(between: "q", and: "p"), 0.0)
        XCTAssertGreaterThanOrEqual(colemak.keyDistance(between: "q", and: "p"), 0.0)
    }
}
