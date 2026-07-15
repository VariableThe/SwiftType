import Foundation

/// Defines available built-in dictionary categories.
public enum DictionaryCategory: String, Sendable, CaseIterable, Codable {
    case english = "English"
    case programming = "Programming"
    case technical = "Technical"
    case cybersecurity = "Cybersecurity"
    case scientific = "Scientific"
    case user = "User"
}

/// Manages built-in word frequency datasets and seeds/syncs them with SQLiteDatabase.
public final class BuiltinDictionaries: @unchecked Sendable {
    private let db: SQLiteDatabase
    private let lock = NSLock()
    private var memoryCache = [String: Int]() // word -> frequency cache

    public init(database: SQLiteDatabase) {
        self.db = database
    }

    /// Populates the SQLiteDatabase with all default built-in dictionaries if they haven't been seeded yet.
    public func seedDefaultDictionariesIfNeeded() throws {
        lock.lock()
        defer { lock.unlock() }

        // Check if database already has words seeded
        if let check = db.getWordFrequency("the"), check > 0 {
            try seedEnglishSupplements()
            loadMemoryCache()
            return
        }

        try db.transaction {
            try seedEnglish()
            try seedEnglishSupplements()
            try seedProgramming()
            try seedTechnical()
            try seedCybersecurity()
            try seedScientific()
        }
        loadMemoryCache()
    }

    private func loadMemoryCache() {
        memoryCache.removeAll(keepingCapacity: true)
        let allWords = db.allWords()
        for word in allWords {
            if let freq = db.getWordFrequency(word) {
                memoryCache[word] = freq
            }
        }
    }

    /// Stage 1 $O(1)$ exact lookup from memory cache or database.
    public func exactFrequency(for word: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        let lower = word.lowercased()
        if let hit = memoryCache[lower] {
            return hit
        }
        if let hit = db.getWordFrequency(lower) {
            memoryCache[lower] = hit
            return hit
        }
        return nil
    }

    /// Returns all words from memory cache for rapid indexing in Stage 2 (SymSpell) and Stage 3 (BK-Tree).
    public func allCachedWords(filteredByCategories categories: Set<String>? = nil) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if let cats = categories, !cats.isEmpty {
            var result = [String]()
            for cat in cats {
                result.append(contentsOf: db.allWords(inDictionary: cat))
            }
            return result
        }
        return Array(memoryCache.keys)
    }

    // MARK: - Seeding Data
    private func seedEnglish() throws {
        let words: [String: Int] = [
            "the": 10000, "of": 9000, "and": 8500, "a": 8000, "to": 7800, "in": 7500, "is": 7200, "you": 7000,
            "that": 6800, "it": 6500, "he": 6000, "was": 5800, "for": 5500, "on": 5200, "are": 5000, "as": 4800,
            "with": 4600, "his": 4400, "they": 4200, "i": 4000, "at": 3800, "be": 3600, "this": 3500, "have": 3400,
            "from": 3300, "or": 3200, "one": 3100, "had": 3000, "by": 2900, "word": 2800, "but": 2700, "not": 2600,
            "what": 2500, "all": 2400, "were": 2300, "we": 2200, "when": 2100, "your": 2000, "can": 1950, "said": 1900,
            "there": 1850, "use": 1800, "an": 1750, "each": 1700, "which": 1650, "she": 1600, "do": 1550, "how": 1500,
            "their": 1450, "if": 1400, "will": 1350, "up": 1300, "other": 1250, "about": 1200, "out": 1150, "many": 1100,
            "then": 1050, "them": 1000, "these": 950, "so": 900, "some": 850, "her": 800, "would": 780, "make": 760,
            "like": 740, "him": 720, "into": 700, "time": 680, "has": 660, "look": 640, "two": 620, "more": 600,
            "write": 580, "go": 560, "see": 540, "number": 520, "no": 500, "way": 490, "could": 480, "people": 470,
            "my": 460, "than": 450, "first": 440, "water": 430, "been": 420, "call": 410, "who": 400, "oil": 390,
            "its": 380, "now": 370, "find": 360, "long": 350, "down": 340, "day": 330, "did": 320, "get": 310,
            "come": 300, "made": 295, "may": 290, "part": 285, "over": 280, "new": 275, "sound": 270, "take": 265,
            "only": 260, "little": 255, "work": 250, "know": 245, "place": 240, "year": 235, "live": 230, "me": 225,
            "back": 220, "give": 215, "most": 210, "very": 205, "after": 200, "thing": 195, "our": 190, "just": 185,
            "name": 180, "good": 175, "sentence": 170, "man": 165, "think": 160, "say": 155, "great": 150, "where": 145,
            "help": 140, "through": 135, "much": 130, "before": 125, "line": 120, "right": 115, "too": 110, "mean": 105,
            "old": 100, "any": 98, "same": 96, "tell": 94, "boy": 92, "follow": 90, "came": 88, "want": 86,
            "show": 84, "also": 82, "around": 80, "form": 78, "three": 76, "small": 74, "set": 72, "put": 70,
            "end": 68, "does": 66, "another": 64, "well": 62, "large": 60, "must": 58, "big": 56, "even": 54,
            "such": 52, "because": 500, "turn": 48, "here": 46, "why": 44, "ask": 42, "went": 40, "men": 38,
            "read": 36, "need": 34, "land": 32, "different": 30, "home": 28, "us": 26, "move": 24, "try": 22,
            "kind": 20, "hand": 19, "picture": 18, "again": 17, "change": 16, "off": 15, "play": 14, "spell": 13,
            "air": 12, "away": 11, "animal": 10, "house": 10, "point": 10, "page": 10, "letter": 10, "mother": 10,
            "answer": 10, "found": 10, "study": 10, "still": 10, "learn": 10, "should": 10, "america": 10, "world": 10,
            "garbage": 450, "recommend": 400, "definitely": 400, "address": 450, "occurred": 350, "accommodate": 350,
            "until": 300, "sense": 300, "separate": 300, "receive": 350, "tomorrow": 350, "truly": 250, "weird": 250,
            "whether": 300, "aggressive": 250, "apparent": 250, "friend": 400, "government": 400, "happened": 350
        ]
        for (w, f) in words {
            try db.insertWord(w, dictionary: DictionaryCategory.english.rawValue, frequency: f)
        }
    }

    /// Additions to the core English dictionary that must also be backfilled for existing databases.
    private func seedEnglishSupplements() throws {
        let words: [String: Int] = [
            "sure": 1800,
            "second": 1200,
            "going": 1500,
            "being": 1400, "doing": 1350, "having": 1300, "getting": 1250, "making": 1200,
            "really": 1200, "already": 1150, "always": 1100, "almost": 1050, "anything": 1000,
            "something": 1000, "nothing": 950, "everything": 950, "someone": 900, "everyone": 900,
            "another": 900, "through": 875, "though": 850, "thought": 825, "without": 800,
            "within": 775, "between": 750, "against": 725, "around": 700, "before": 675,
            "after": 650, "again": 625, "because": 1200, "while": 600, "where": 575,
            "which": 1100, "what": 1600, "when": 1500, "why": 900, "who": 900,
            "whose": 500, "could": 1000, "should": 1000, "would": 1000, "might": 800,
            "their": 1100, "there": 1100, "they": 1000, "then": 950, "than": 900,
            "these": 850, "those": 825, "your": 1000, "about": 1000,
            "actually": 850, "probably": 800, "definitely": 900, "different": 800, "important": 750,
            "possible": 700, "problem": 675, "question": 650, "answer": 625, "example": 600,
            "system": 575, "software": 550, "computer": 525, "keyboard": 500, "sentence": 475,
            "correct": 700, "correction": 650, "changed": 500, "working": 600, "typing": 550,
            "language": 500, "english": 475, "people": 700, "person": 600, "place": 550,
            "thing": 650, "things": 625, "first": 800, "last": 700, "next": 675,
            "better": 700, "best": 650, "good": 900, "great": 700, "small": 600,
            "large": 550, "long": 650, "short": 550, "right": 800, "wrong": 700,
            "high": 600, "low": 500, "same": 800, "such": 700, "much": 750,
            "many": 750, "most": 725, "more": 900, "less": 525, "least": 500,
            "still": 700, "also": 800, "just": 900, "even": 800, "only": 850,
            "well": 750, "very": 850, "every": 700, "each": 650, "both": 625,
            "under": 600, "over": 600, "into": 700, "from": 1000, "with": 1200,
            "using": 800, "called": 575, "found": 550, "write": 650, "written": 550,
            "read": 600, "learn": 550, "build": 525, "built": 500, "open": 575,
            "close": 500, "start": 650, "stop": 550, "press": 500, "allow": 475
        ]
        for (w, f) in words {
            try db.insertWord(w, dictionary: DictionaryCategory.english.rawValue, frequency: f)
        }
    }

    private func seedProgramming() throws {
        // High frequency weights for technical/programming terms so they override generic collisions
        let vocab: [String: Int] = [
            "swift": 5000, "rust": 4500, "python": 5000, "javascript": 5000, "typescript": 5000,
            "react": 4800, "swiftui": 5000, "electron": 4000, "docker": 4500, "git": 5000,
            "github": 5000, "raycast": 4500, "homebrew": 4200, "hyprland": 3500, "nextcloud": 3500,
            "pipewire": 3500, "wayland": 3800, "linux": 4800, "macos": 5000, "cachyos": 3000,
            "arch": 4000, "fedora": 4000, "obsidian": 4200, "sqlite": 4800, "postgresql": 4500,
            "redis": 4500, "xcode": 4800, "combine": 4000, "appkit": 4200, "cocoa": 3800,
            "cgevent": 4000, "cgeventtap": 4000, "axuielement": 4000, "symspell": 4000, "bktree": 4000,
            "levenshtein": 3800, "damerau": 3800, "mvvm": 4200, "async": 4500, "await": 4500,
            "actor": 4200, "sendable": 4500, "viewmodel": 4500, "observableobject": 4500, "published": 4500,
            "struct": 4500, "enum": 4500, "protocol": 4500, "extension": 4500, "closure": 4200,
            "golang": 4000, "kotlin": 4200, "java": 4500, "ruby": 3800, "php": 3800, "csharp": 4000,
            "cpp": 4200, "wasm": 3800, "webassembly": 3800, "nodejs": 4500, "deno": 3500, "bun": 3800,
            "nextjs": 4500, "vite": 4200, "webpack": 3800, "tailwindcss": 4200, "vue": 4000, "angular": 3800,
            "svelte": 4000, "fastapi": 4000, "django": 4000, "flask": 3800, "spring": 4000, "aspnet": 3800
        ]
        for (w, f) in vocab {
            try db.insertWord(w, dictionary: DictionaryCategory.programming.rawValue, frequency: f)
        }
    }

    private func seedTechnical() throws {
        let vocab: [String: Int] = [
            "api": 4500, "sdk": 4500, "cpu": 4500, "gpu": 4500, "ram": 4500, "ssd": 4200, "nvme": 3800,
            "http": 4800, "https": 4800, "tcp": 4200, "udp": 4000, "dns": 4500, "dhcp": 3800,
            "json": 4800, "yaml": 4500, "xml": 4000, "rest": 4500, "graphql": 4200, "cicd": 4200,
            "kubernetes": 4500, "terraform": 4200, "ansible": 4000, "microservices": 4000, "serverless": 4000,
            "cloud": 4500, "aws": 4800, "gcp": 4500, "azure": 4500, "bandwidth": 3800, "latency": 4500,
            "throughput": 4000, "concurrency": 4200, "parallelism": 4000, "multithreading": 4000, "mutex": 4000,
            "semaphore": 3800, "deadlock": 3800, "cache": 4500, "buffer": 4200, "algorithm": 4500
        ]
        for (w, f) in vocab {
            try db.insertWord(w, dictionary: DictionaryCategory.technical.rawValue, frequency: f)
        }
    }

    private func seedCybersecurity() throws {
        let vocab: [String: Int] = [
            "firewall": 4000, "ransomware": 4000, "phishing": 4200, "malware": 4500, "wireshark": 3800,
            "metasploit": 3500, "burpsuite": 3800, "nmap": 4000, "kali": 3800, "cryptography": 4000,
            "authorization": 4500, "authentication": 4500, "vulnerability": 4500, "exploit": 4200,
            "penetration": 3800, "zeroday": 3800, "encryption": 4500, "decryption": 4200, "sha256": 4200,
            "aes": 4200, "rsa": 4000, "jwt": 4200, "oauth": 4500, "saml": 3800, "tls": 4500, "ssl": 4200,
            "sql": 4800, "xss": 4000, "csrf": 3800, "ddos": 4200, "botnet": 3800, "rootkit": 3500
        ]
        for (w, f) in vocab {
            try db.insertWord(w, dictionary: DictionaryCategory.cybersecurity.rawValue, frequency: f)
        }
    }

    private func seedScientific() throws {
        let vocab: [String: Int] = [
            "hypothesis": 3800, "empirical": 3500, "quantitative": 3800, "qualitative": 3800,
            "thermodynamic": 3200, "quantum": 3800, "genomic": 3500, "statistical": 4000,
            "covariance": 3200, "equilibrium": 3500, "kinetics": 3200, "molecular": 3800,
            "cellular": 3800, "phenotype": 3500, "genotype": 3500, "bioinformatics": 3800,
            "stochastic": 3500, "deterministic": 3800, "asymptotic": 3500, "logarithmic": 3800,
            "exponential": 4000, "polynomial": 3800, "eigenvalue": 3500, "eigenvector": 3500
        ]
        for (w, f) in vocab {
            try db.insertWord(w, dictionary: DictionaryCategory.scientific.rawValue, frequency: f)
        }
    }
}
