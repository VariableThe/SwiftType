import Foundation

/// Stage 2: Symmetric Delete spelling correction algorithm (SymSpell) for ultra-fast edit distance candidate generation.
public final class SymSpellEngine: @unchecked Sendable {
    private let maxEditDistance: Int
    private var deletesMap = [String: Set<String>]() // delete string -> set of dictionary words
    private var wordsList = Set<String>()
    private let lock = NSLock()

    public init(maxEditDistance: Int = 2) {
        self.maxEditDistance = maxEditDistance
    }

    /// Indexes a list of dictionary words into the symmetric delete map.
    public func indexWords(_ words: [String]) {
        lock.lock()
        defer { lock.unlock() }
        for word in words {
            let lower = word.lowercased()
            guard !lower.isEmpty && lower.count <= 30 else { continue }
            if wordsList.contains(lower) { continue }
            wordsList.insert(lower)

            let deletes = SymSpellEngine.generateDeletes(for: lower, maxDistance: maxEditDistance)
            for del in deletes {
                if deletesMap[del] != nil {
                    deletesMap[del]?.insert(lower)
                } else {
                    deletesMap[del] = [lower]
                }
            }
        }
    }

    /// Indexes a single word into the map dynamically (e.g. when user learns a new word).
    public func indexWord(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let lower = word.lowercased()
        guard !wordsList.contains(lower) else { return }
        wordsList.insert(lower)
        let deletes = SymSpellEngine.generateDeletes(for: lower, maxDistance: maxEditDistance)
        for del in deletes {
            if deletesMap[del] != nil {
                deletesMap[del]?.insert(lower)
            } else {
                deletesMap[del] = [lower]
            }
        }
    }

    /// Clears the index.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        deletesMap.removeAll(keepingCapacity: true)
        wordsList.removeAll(keepingCapacity: true)
    }

    /// Performs Stage 2 candidate generation by checking symmetric deletes of the query string.
    /// Returns unique dictionary words whose edit distance to query is <= maxEditDistance.
    public func lookup(_ query: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        let lower = query.lowercased()
        guard !lower.isEmpty && lower.count <= 35 else { return [] }

        // If exact word exists in dictionary, include it
        var candidates = Set<String>()
        if wordsList.contains(lower) {
            candidates.insert(lower)
        }

        let queryDeletes = SymSpellEngine.generateDeletes(for: lower, maxDistance: maxEditDistance)
        for del in queryDeletes {
            if let matchedWords = deletesMap[del] {
                for word in matchedWords {
                    // Check exact Levenshtein / Damerau distance
                    if abs(word.count - lower.count) <= maxEditDistance {
                        if SymSpellEngine.damerauLevenshteinDistance(lower, word) <= maxEditDistance {
                            candidates.insert(word)
                        }
                    }
                }
            }
        }
        return candidates
    }

    // MARK: - Static Delete Generator
    private static func generateDeletes(for string: String, maxDistance: Int) -> Set<String> {
        var deletes = Set<String>()
        deletes.insert(string)
        guard maxDistance > 0 && string.count > 1 else { return deletes }

        var queue = [string]
        var visited = Set<String>()
        visited.insert(string)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let distance = string.count - current.count
            if distance < maxDistance && current.count > 1 {
                let chars = Array(current)
                for i in 0..<chars.count {
                    var candidateChars = chars
                    candidateChars.remove(at: i)
                    let candidateStr = String(candidateChars)
                    if !visited.contains(candidateStr) {
                        visited.insert(candidateStr)
                        deletes.insert(candidateStr)
                        queue.append(candidateStr)
                    }
                }
            }
        }
        return deletes
    }

    // MARK: - Damerau-Levenshtein Distance Helper
    public static func damerauLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
        if s1 == s2 { return 0 }
        let chars1 = Array(s1)
        let chars2 = Array(s2)
        let len1 = chars1.count
        let len2 = chars2.count
        if len1 == 0 { return len2 }
        if len2 == 0 { return len1 }

        var dp = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        for i in 0...len1 { dp[i][0] = i }
        for j in 0...len2 { dp[0][j] = j }

        for i in 1...len1 {
            for j in 1...len2 {
                let cost = (chars1[i - 1] == chars2[j - 1]) ? 0 : 1
                var minVal = min(
                    dp[i - 1][j] + 1,       // Deletion
                    dp[i][j - 1] + 1,       // Insertion
                    dp[i - 1][j - 1] + cost // Substitution
                )
                if i > 1 && j > 1 && chars1[i - 1] == chars2[j - 2] && chars1[i - 2] == chars2[j - 1] {
                    minVal = min(minVal, dp[i - 2][j - 2] + cost) // Transposition
                }
                dp[i][j] = minVal
            }
        }
        return dp[len1][len2]
    }
}
