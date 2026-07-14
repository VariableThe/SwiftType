import Foundation
import Combine

public enum KeyboardLayoutType: String, Sendable, CaseIterable, Codable {
    case qwerty = "QWERTY"
    case dvorak = "Dvorak"
    case colemak = "Colemak"
}

/// Reactive SettingsManager handling configuration persistence via SQLiteDatabase and Combine.
public final class SettingsManager: ObservableObject, @unchecked Sendable {
    private let db: SQLiteDatabase
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()

    @Published public var confidenceThreshold: Double {
        didSet { saveSetting(key: "confidenceThreshold", value: "\(confidenceThreshold)") }
    }
    
    @Published public var enableLearning: Bool {
        didSet { saveSetting(key: "enableLearning", value: enableLearning ? "true" : "false") }
    }
    
    @Published public var learningThreshold: Int {
        didSet { saveSetting(key: "learningThreshold", value: "\(learningThreshold)") }
    }
    
    @Published public var keyboardLayout: KeyboardLayoutType {
        didSet { saveSetting(key: "keyboardLayout", value: keyboardLayout.rawValue) }
    }
    
    @Published public var correctionDelayMs: Double {
        didSet { saveSetting(key: "correctionDelayMs", value: "\(correctionDelayMs)") }
    }
    
    @Published public var correctionSounds: Bool {
        didSet { saveSetting(key: "correctionSounds", value: correctionSounds ? "true" : "false") }
    }
    
    @Published public var animationToggle: Bool {
        didSet { saveSetting(key: "animationToggle", value: animationToggle ? "true" : "false") }
    }
    
    @Published public var languageSelection: String {
        didSet { saveSetting(key: "languageSelection", value: languageSelection) }
    }
    
    @Published public var enabledDictionaries: Set<String> {
        didSet {
            let joined = enabledDictionaries.sorted().joined(separator: ",")
            saveSetting(key: "enabledDictionaries", value: joined)
        }
    }

    public init(database: SQLiteDatabase) {
        self.db = database
        
        // Defaults
        var initialConfidence = 0.95
        var initialLearning = true
        var initialLearningThreshold = 3
        var initialLayout = KeyboardLayoutType.qwerty
        var initialDelay = 0.0
        var initialSounds = true
        var initialAnimations = true
        var initialLanguage = "English"
        var initialDictionaries: Set<String> = ["English", "Programming", "Technical", "User"]

        if let confStr = db.getSetting(key: "confidenceThreshold"), let val = Double(confStr) {
            initialConfidence = val
        }
        if let learnStr = db.getSetting(key: "enableLearning") {
            initialLearning = (learnStr == "true")
        }
        if let threshStr = db.getSetting(key: "learningThreshold"), let val = Int(threshStr) {
            initialLearningThreshold = val
        }
        if let layoutStr = db.getSetting(key: "keyboardLayout"), let layout = KeyboardLayoutType(rawValue: layoutStr) {
            initialLayout = layout
        }
        if let delayStr = db.getSetting(key: "correctionDelayMs"), let val = Double(delayStr) {
            initialDelay = val
        }
        if let soundStr = db.getSetting(key: "correctionSounds") {
            initialSounds = (soundStr == "true")
        }
        if let animStr = db.getSetting(key: "animationToggle") {
            initialAnimations = (animStr == "true")
        }
        if let langStr = db.getSetting(key: "languageSelection") {
            initialLanguage = langStr
        }
        if let dictStr = db.getSetting(key: "enabledDictionaries") {
            let items = dictStr.split(separator: ",").map { String($0) }
            initialDictionaries = Set(items)
        }

        self.confidenceThreshold = initialConfidence
        self.enableLearning = initialLearning
        self.learningThreshold = initialLearningThreshold
        self.keyboardLayout = initialLayout
        self.correctionDelayMs = initialDelay
        self.correctionSounds = initialSounds
        self.animationToggle = initialAnimations
        self.languageSelection = initialLanguage
        self.enabledDictionaries = initialDictionaries
    }

    private func saveSetting(key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        try? db.setSetting(key: key, value: value)
    }
}
