import Foundation

/// Node inside a Burkhard-Keller (BK) metric tree.
final class BKNode: @unchecked Sendable {
    let word: String
    var children = [Int: BKNode]() // edge weight (distance) -> child node

    init(word: String) {
        self.word = word
    }
}

/// Stage 3: Burkhard-Keller metric tree lookup using Damerau-Levenshtein distance for nearest-neighbor search.
public final class BKTreeEngine: @unchecked Sendable {
    private var root: BKNode?
    private let lock = NSLock()

    public init() {}

    /// Inserts a word into the BK-Tree.
    public func insert(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let lower = word.lowercased()
        guard !lower.isEmpty else { return }

        guard let root = root else {
            self.root = BKNode(word: lower)
            return
        }

        var current = root
        while true {
            let dist = SymSpellEngine.damerauLevenshteinDistance(current.word, lower)
            if dist == 0 { return } // Word already present inside tree
            if let next = current.children[dist] {
                current = next
            } else {
                current.children[dist] = BKNode(word: lower)
                break
            }
        }
    }

    /// Inserts a batch of words into the tree.
    public func insertBatch(_ words: [String]) {
        for word in words {
            insert(word)
        }
    }

    /// Clears the entire tree.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        root = nil
    }

    /// Searches the BK-Tree for all words whose Damerau-Levenshtein distance to `query` is <= `maxDistance`.
    /// Prunes subtrees outside the triangle inequality bounds [dist - maxDistance, dist + maxDistance].
    public func search(query: String, maxDistance: Int = 2) -> [(word: String, distance: Int)] {
        lock.lock()
        defer { lock.unlock() }
        guard let root = root, !query.isEmpty else { return [] }

        let lower = query.lowercased()
        var results = [(word: String, distance: Int)]()
        var queue = [root]

        while !queue.isEmpty {
            let current = queue.removeLast()
            let dist = SymSpellEngine.damerauLevenshteinDistance(current.word, lower)
            if dist <= maxDistance {
                results.append((word: current.word, distance: dist))
            }

            let minBound = dist - maxDistance
            let maxBound = dist + maxDistance
            for (edgeDist, child) in current.children {
                if edgeDist >= minBound && edgeDist <= maxBound {
                    queue.append(child)
                }
            }
        }
        return results
    }
}
