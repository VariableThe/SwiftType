import SwiftUI
import AppKit
import SwiftTypeCore
import SwiftTypeSystem
import SwiftTypeUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let sharedDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    var menuBarController: MenuBarController?
    var database: SQLiteDatabase!
    var settings: SettingsManager!
    var statistics: StatisticsService!
    var engine: SmartCorrectionEngine!
    var autoLearning: AutoLearningManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application policy to accessory (menu bar agent without dock icon clutter)
        NSApp.setActivationPolicy(.accessory)

        // Initialize SQLite Database in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let swiftTypeDir = appSupport.appendingPathComponent("SwiftType", isDirectory: true)
        try? FileManager.default.createDirectory(at: swiftTypeDir, withIntermediateDirectories: true)
        let dbPath = swiftTypeDir.appendingPathComponent("swifttype.sqlite").path

        do {
            database = try SQLiteDatabase(path: dbPath)
        } catch {
            // Fallback to in-memory if disk permission fails
            database = try! SQLiteDatabase.inMemory()
        }

        settings = SettingsManager(database: database)
        statistics = StatisticsService(database: database)
        let dicts = BuiltinDictionaries(database: database)
        engine = SmartCorrectionEngine(database: database, dictionaries: dicts)
        autoLearning = AutoLearningManager(database: database, settings: settings, engine: engine)

        // Pre-index dictionaries into SymSpell ($O(1)$) and BK-Tree metrics
        engine.prepareIndexIfNeeded()

        // Initialize Menu Bar controller and start monitoring if permissions trusted
        menuBarController = MenuBarController(
            settings: settings,
            statistics: statistics,
            autoLearning: autoLearning,
            database: database,
            engine: engine
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalEventTap.shared.stop()
    }
}
