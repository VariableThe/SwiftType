import SwiftUI
import SwiftTypeCore
import SwiftTypeSystem

/// Comprehensive Settings and Preferences interface for SwiftType.
public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var statistics: StatisticsService
    @ObservedObject var autoLearning: AutoLearningManager
    let database: SQLiteDatabase
    let engine: SmartCorrectionEngine

    @State private var selectedTab: SettingsTab = .general
    @State private var newWordInput: String = ""
    @State private var ignoreRuleInput: String = ""
    @State private var replacementInput: String = ""
    @State private var userWordsList: [String] = []

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case dictionaries = "Dictionaries"
        case learning = "Learning & Exceptions"
        case performance = "Performance"

        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .general: return "gearshape"
            case .dictionaries: return "book.closed"
            case .learning: return "brain.head.profile"
            case .performance: return "gauge.medium"
            }
        }
    }

    public init(settings: SettingsManager, statistics: StatisticsService, autoLearning: AutoLearningManager, database: SQLiteDatabase, engine: SmartCorrectionEngine) {
        self.settings = settings
        self.statistics = statistics
        self.autoLearning = autoLearning
        self.database = database
        self.engine = engine
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .dictionaries:
                        dictionariesTab
                    case .learning:
                        learningTab
                    case .performance:
                        performanceTab
                    }
                }
                .padding(24)
            }
            .navigationTitle(selectedTab.rawValue)
        }
        .frame(width: 720, height: 520)
        .onAppear {
            refreshUserWords()
        }
    }

    // MARK: - General Tab
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Enable System-Wide Autocorrect", isOn: $settings.enableAutocorrect)
                .font(.headline)

            Toggle("Play Sound on Correction", isOn: $settings.playSoundOnCorrection)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Confidence Threshold: \(Int(settings.confidenceThreshold * 100))%")
                    .font(.subheadline)
                Slider(value: $settings.confidenceThreshold, in: 0.70...1.0, step: 0.01)
                Text("Higher values require closer keyboard proximity and higher algorithm confidence before triggering a replacement.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Text("Global Status Indicator:")
                Spacer()
                Text(GlobalEventTap.shared.isMonitoring ? "Active & Trusted" : "Paused / Untrusted")
                    .foregroundColor(GlobalEventTap.shared.isMonitoring ? .green : .red)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Dictionaries Tab
    private var dictionariesTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Specialized Vocabulary Modules")
                .font(.headline)

            Toggle("Programming & CLI Commands (Swift, Rust, Python, Docker, Git)", isOn: $settings.enableProgrammingDict)
            Toggle("Technical & Systems Terms (Wayland, Arch, Homebrew, SQLite)", isOn: $settings.enableTechnicalDict)
            Toggle("Scientific & Medical Terminology", isOn: $settings.enableScientificDict)

            Divider()

            Text("Custom User Dictionary (\(userWordsList.count) words)")
                .font(.headline)

            HStack {
                TextField("Add custom word...", text: $newWordInput)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let clean = newWordInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !clean.isEmpty {
                        try? database.addUserWord(clean)
                        engine.indexNewWord(clean)
                        newWordInput = ""
                        refreshUserWords()
                    }
                }
                .disabled(newWordInput.isEmpty)
            }

            List {
                ForEach(userWordsList, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button {
                            try? database.removeUserWord(word)
                            refreshUserWords()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Learning Tab
    private var learningTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Automatic Word Learning", isOn: $settings.enableLearning)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Learning Threshold: \(settings.learningThreshold) uncorrected uses")
                Stepper("Observed \(settings.learningThreshold) times before auto-adding", value: $settings.learningThreshold, in: 1...10)
            }

            Divider()

            Text("Pending Word Suggestions (\(autoLearning.pendingSuggestions.count))")
                .font(.headline)

            if autoLearning.pendingSuggestions.isEmpty {
                Text("No pending suggestions at this time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                List(autoLearning.pendingSuggestions) { suggestion in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(suggestion.word).fontWeight(.bold)
                            Text("Typed \(suggestion.useCount) times without correction").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Approve") {
                            autoLearning.approveSuggestion(suggestion)
                            refreshUserWords()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Dismiss") {
                            autoLearning.dismissSuggestion(suggestion)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: - Performance Tab
    private var performanceTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Engine Performance Metrics")
                .font(.headline)

            HStack {
                Text("Average Correction Latency:")
                Spacer()
                Text(String(format: "%.2f ms", statistics.metrics.averageLatencyMs))
                    .fontWeight(.bold)
                    .foregroundColor(statistics.metrics.averageLatencyMs <= 5.0 ? .green : .orange)
            }

            HStack {
                Text("Target Latency SLA:")
                Spacer()
                Text("< 5.00 ms")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Memory Footprint Index:")
                Spacer()
                Text("Prepared & Active ($O(1)$ SymSpell + BK-Tree)")
                    .foregroundColor(.blue)
            }

            Divider()

            Button("Force Re-Index Dictionaries") {
                engine.prepareIndexIfNeeded()
            }
            .buttonStyle(.bordered)
        }
    }

    private func refreshUserWords() {
        userWordsList = database.getAllUserWords().sorted()
    }
}
