import Foundation
import AppKit
import SwiftUI
import SwiftTypeCore
import SwiftTypeSystem

/// Manages the system-wide Menu Bar extra icon, status dropdown, and quick toggle actions.
@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var settings: SettingsManager
    private var statistics: StatisticsService
    private var autoLearning: AutoLearningManager
    private var database: SQLiteDatabase
    private var engine: SmartCorrectionEngine

    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    public init(settings: SettingsManager, statistics: StatisticsService, autoLearning: AutoLearningManager, database: SQLiteDatabase, engine: SmartCorrectionEngine) {
        self.settings = settings
        self.statistics = statistics
        self.autoLearning = autoLearning
        self.database = database
        self.engine = engine
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "SwiftType Autocorrect")
        }
        rebuildMenu()

        // Check permissions on startup asynchronously after run loop initialization
        if !AccessibilityCoordinator.shared.isTrusted {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        } else {
            GlobalEventTap.shared.configure(engine: engine, settings: settings, statistics: statistics, autoLearning: autoLearning)
            GlobalEventTap.shared.start()
            updateStatusIcon()
        }
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        // 1. Status Header
        let isTrusted = AccessibilityCoordinator.shared.isTrusted
        let isMonitoring = GlobalEventTap.shared.isMonitoring && settings.enableAutocorrect
        
        let statusTitle = !isTrusted ? "Status: Permissions Required" : (isMonitoring ? "Status: Active & System-Wide" : "Status: Paused")
        let statusItemMenu = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItemMenu.image = NSImage(systemSymbolName: !isTrusted ? "exclamationmark.triangle.fill" : (isMonitoring ? "checkmark.circle.fill" : "pause.circle.fill"), accessibilityDescription: nil)
        menu.addItem(statusItemMenu)

        menu.addItem(NSMenuItem.separator())

        // 2. Quick Toggle
        let toggleTitle = settings.enableAutocorrect ? "Pause Autocorrect" : "Resume Autocorrect"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAutocorrect), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Quick Stats
        let statsTitle = "Saved \(statistics.metrics.totalKeystrokesSaved) keystrokes (\(statistics.metrics.totalCorrections) words)"
        let statsItem = NSMenuItem(title: statsTitle, action: nil, keyEquivalent: "")
        menu.addItem(statsItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Windows
        let dashItem = NSMenuItem(title: "Statistics Dashboard...", action: #selector(openDashboard), keyEquivalent: "d")
        dashItem.target = self
        menu.addItem(dashItem)

        let settingsItem = NSMenuItem(title: "Settings & Preferences...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        if !isTrusted {
            let permItem = NSMenuItem(title: "Grant Permissions...", action: #selector(showOnboarding), keyEquivalent: "p")
            permItem.target = self
            menu.addItem(permItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
        let quitItem = NSMenuItem(title: "Quit SwiftType", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    public func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        if !AccessibilityCoordinator.shared.isTrusted {
            button.image = NSImage(systemSymbolName: "keyboard.badge.exclamationmark", accessibilityDescription: "Permissions Required")
        } else if !settings.enableAutocorrect || !GlobalEventTap.shared.isMonitoring {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Paused")
        } else {
            button.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Active")
        }
        rebuildMenu()
    }

    @objc private func toggleAutocorrect() {
        settings.enableAutocorrect.toggle()
        if settings.enableAutocorrect {
            GlobalEventTap.shared.start()
        } else {
            GlobalEventTap.shared.stop()
        }
        updateStatusIcon()
    }

    @objc public func openDashboard() {
        if dashboardWindow == nil {
            let view = StatisticsDashboardView(statistics: statistics)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SwiftType Performance Dashboard"
            window.contentViewController = controller
            window.center()
            window.isReleasedWhenClosed = false
            self.dashboardWindow = window
        }
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, statistics: statistics, autoLearning: autoLearning, database: database, engine: engine)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SwiftType Settings & Preferences"
            window.contentViewController = controller
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView { [weak self] in
                guard let self else { return }
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.updateStatusIcon()
                GlobalEventTap.shared.configure(
                    engine: self.engine,
                    settings: self.settings,
                    statistics: self.statistics,
                    autoLearning: self.autoLearning
                )
                GlobalEventTap.shared.start()
            }
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "SwiftType Onboarding & Permissions"
            window.contentViewController = controller
            window.center()
            window.isReleasedWhenClosed = false
            self.onboardingWindow = window
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        GlobalEventTap.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}
