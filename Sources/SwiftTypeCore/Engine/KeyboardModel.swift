import Foundation

/// Coordinates representing a key on a physical keyboard layout.
public struct KeyCoordinate: Sendable, Equatable {
    public let row: Double
    public let col: Double

    public init(row: Double, col: Double) {
        self.row = row
        self.col = col
    }

    public func euclideanDistance(to other: KeyCoordinate) -> Double {
        let dRow = self.row - other.row
        let dCol = self.col - other.col
        return (dRow * dRow + dCol * dCol).squareRoot()
    }
}

/// Provides physical keyboard coordinate models, distance penalties, and human typo exemption mappings.
public final class KeyboardModel: @unchecked Sendable {
    private let layout: KeyboardLayoutType
    private let keyCoordinates: [Character: KeyCoordinate]
    
    /// Exact mappings for notorious human typing mistakes that should always receive maximum exemption / minimal cost.
    public static let commonTypoExemptions: [String: String] = [
        "teh": "the",
        "becuase": "because",
        "becasue": "because",
        "garabage": "garbage",
        "reccomend": "recommend",
        "definately": "definitely",
        "definitly": "definitely",
        "adress": "address",
        "occured": "occurred",
        "acommodate": "accommodate",
        "untill": "until",
        "sence": "sense",
        "seperate": "separate",
        "recieve": "receive",
        "alot": "a lot",
        "tomorow": "tomorrow",
        "truely": "truly",
        "wierd": "weird",
        "wether": "whether",
        "agressive": "aggressive",
        "apparant": "apparent",
        "freind": "friend",
        "thier": "their",
        "govment": "government",
        "happend": "happened",
        "goign": "going",
        "whay": "what",
        "whar": "what"
    ]

    public init(layout: KeyboardLayoutType = .qwerty) {
        self.layout = layout
        self.keyCoordinates = KeyboardModel.generateCoordinates(for: layout)
    }

    /// Returns the physical key distance between two characters on the configured layout.
    public func keyDistance(between c1: Character, and c2: Character) -> Double {
        let char1 = Character(c1.lowercased())
        let char2 = Character(c2.lowercased())
        if char1 == char2 { return 0.0 }
        
        guard let coord1 = keyCoordinates[char1], let coord2 = keyCoordinates[char2] else {
            return 2.5 // Default fallback penalty for unmapped characters/symbols
        }
        return coord1.euclideanDistance(to: coord2)
    }

    /// Returns a normalized substitution cost between 0.1 and 1.0 based on physical keyboard proximity.
    /// Adjacent keys like (r <-> e), (t <-> y), (m <-> n) return low penalties (~0.2 - 0.4).
    public func substitutionCost(from c1: Character, to c2: Character) -> Double {
        if c1.lowercased() == c2.lowercased() { return 0.0 }
        let dist = keyDistance(between: c1, and: c2)
        if dist <= 1.1 {
            return 0.25 // Immediately adjacent keys (e.g. r <-> e, t <-> y, m <-> n)
        } else if dist <= 1.6 {
            return 0.55 // Diagonal or nearby keys
        } else {
            return min(1.0, dist * 0.4)
        }
    }

    /// Calculates a weighted keyboard-aware edit cost between a typo candidate and a target dictionary word.
    /// Incorporates common typo exemptions, transposition discounts, and double-letter rules.
    public func weightedEditCost(source: String, target: String) -> Double {
        let lowerSource = source.lowercased()
        let lowerTarget = target.lowercased()
        if lowerSource == lowerTarget { return 0.0 }

        // 1. Exact common typo exemption check
        if let exempted = KeyboardModel.commonTypoExemptions[lowerSource], exempted == lowerTarget {
            return 0.1 // Extremely small cost to guarantee top ranking
        }

        let sChars = Array(lowerSource)
        let tChars = Array(lowerTarget)
        let sLen = sChars.count
        let tLen = tChars.count

        // Dynamic programming table with weighted costs
        var dp = Array(repeating: Array(repeating: 0.0, count: tLen + 1), count: sLen + 1)
        for i in 0...sLen { dp[i][0] = Double(i) }
        for j in 0...tLen { dp[0][j] = Double(j) }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

        for i in 1...sLen {
            for j in 1...tLen {
                let cost = substitutionCost(from: sChars[i - 1], to: tChars[j - 1])
                var minCost = min(
                    dp[i - 1][j] + 0.95,       // Deletion from source
                    dp[i][j - 1] + 0.95,       // Insertion into source
                    dp[i - 1][j - 1] + cost    // Substitution
                )

                // Transposition discount (e.g. "teh" -> "the" or "becuase" -> "because")
                if i > 1 && j > 1 && sChars[i - 1] == tChars[j - 2] && sChars[i - 2] == tChars[j - 1] {
                    minCost = min(minCost, dp[i - 2][j - 2] + 0.25)
                }

                // Double letter insertion/deletion discount (e.g. "reccomend" -> "recommend", "adress" -> "address")
                if i > 1 && sChars[i - 1] == sChars[i - 2] && sChars[i - 1] == tChars[j - 1] {
                    minCost = min(minCost, dp[i - 1][j] + 0.3) // Duplicate letter penalty reduced
                }
                if j > 1 && tChars[j - 1] == tChars[j - 2] && sChars[i - 1] == tChars[j - 1] {
                    minCost = min(minCost, dp[i][j - 1] + 0.3) // Missing double letter penalty reduced
                }

                // Vowel confusion discount (e.g. "definately" -> "definitely")
                if vowels.contains(sChars[i - 1]) && vowels.contains(tChars[j - 1]) && cost > 0.0 {
                    minCost = min(minCost, dp[i - 1][j - 1] + 0.35)
                }

                dp[i][j] = minCost
            }
        }

        return dp[sLen][tLen]
    }

    // MARK: - Layout Generators
    private static func generateCoordinates(for layout: KeyboardLayoutType) -> [Character: KeyCoordinate] {
        switch layout {
        case .qwerty:
            return generateQWERTY()
        case .dvorak:
            return generateDvorak()
        case .colemak:
            return generateColemak()
        }
    }

    private static func generateQWERTY() -> [Character: KeyCoordinate] {
        var map = [Character: KeyCoordinate]()
        let row1: [Character] = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let row2: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let row3: [Character] = ["z", "x", "c", "v", "b", "n", "m"]

        for (idx, char) in row1.enumerated() {
            map[char] = KeyCoordinate(row: 1.0, col: Double(idx))
        }
        for (idx, char) in row2.enumerated() {
            map[char] = KeyCoordinate(row: 2.0, col: Double(idx) + 0.25)
        }
        for (idx, char) in row3.enumerated() {
            map[char] = KeyCoordinate(row: 3.0, col: Double(idx) + 0.75)
        }
        return map
    }

    private static func generateDvorak() -> [Character: KeyCoordinate] {
        var map = [Character: KeyCoordinate]()
        let row1: [Character] = ["'", ",", ".", "p", "y", "f", "g", "c", "r", "l"]
        let row2: [Character] = ["a", "o", "e", "u", "i", "d", "h", "t", "n", "s"]
        let row3: [Character] = [";", "q", "j", "k", "x", "b", "m", "w", "v", "z"]

        for (idx, char) in row1.enumerated() {
            map[char] = KeyCoordinate(row: 1.0, col: Double(idx))
        }
        for (idx, char) in row2.enumerated() {
            map[char] = KeyCoordinate(row: 2.0, col: Double(idx) + 0.25)
        }
        for (idx, char) in row3.enumerated() {
            map[char] = KeyCoordinate(row: 3.0, col: Double(idx) + 0.75)
        }
        return map
    }

    private static func generateColemak() -> [Character: KeyCoordinate] {
        var map = [Character: KeyCoordinate]()
        let row1: [Character] = ["q", "w", "f", "p", "g", "j", "l", "u", "y", ";"]
        let row2: [Character] = ["a", "r", "s", "t", "d", "h", "n", "e", "i", "o"]
        let row3: [Character] = ["z", "x", "c", "v", "b", "k", "m"]

        for (idx, char) in row1.enumerated() {
            map[char] = KeyCoordinate(row: 1.0, col: Double(idx))
        }
        for (idx, char) in row2.enumerated() {
            map[char] = KeyCoordinate(row: 2.0, col: Double(idx) + 0.25)
        }
        for (idx, char) in row3.enumerated() {
            map[char] = KeyCoordinate(row: 3.0, col: Double(idx) + 0.75)
        }
        return map
    }
}
