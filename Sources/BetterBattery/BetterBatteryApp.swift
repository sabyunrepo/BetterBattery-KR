import SwiftUI
import AppKit
import Combine

@main
enum BetterBatteryApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.run()
    }
}

enum DefaultsKey {
    static let showMenuBarWatts = "showMenuBarWatts"
    static let showMenuBarPercent = "showMenuBarPercent"
    static let showMenuBarTime = "showMenuBarTime"
    static let warnThreshold = "warnThreshold"
    static let criticalThreshold = "criticalThreshold"
    static let lowBatteryGlow = "lowBatteryGlow"
    static let glowWidth = "glowWidth"
    static let plugInCelebration = "plugInCelebration"
    static let historyMode = "historyMode"
    static let showNerdStats = "showNerdStats"
    static let lifetimeDischargeWh = "lifetimeDischargeWh"
    static let lifetimeChargeWh = "lifetimeChargeWh"
    static let historyWindow = "historyWindow"
    static let showTempOverlay = "showTempOverlay"
    static let showSettingsSection = "showSettingsSection"
    static let showLowBatterySection = "showLowBatterySection"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = PowerMonitor.shared
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var snapshotSubscription: AnyCancellable?
    private var defaultsObserver: NSObjectProtocol?
    private var rotationTimer: Timer?
    private var currentMetric: MenuBarMetric = .watts
    private var lastIconKey = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon — this app lives entirely in the menu bar.
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: 42)
        item.autosaveName = "com.batterywatts.app.statusItem"
        statusItem = item
        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageOnly
            button.toolTip = "배터리 전력"
        }

        let controller = NSHostingController(rootView: MenuPanelView(monitor: monitor))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        popover.behavior = .transient

        snapshotSubscription = monitor.$snapshot.sink { [weak self] snapshot in
            self?.refreshStatusItem(with: snapshot)
        }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.advanceMetric()
        }
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if !self.enabledMetrics.contains(self.currentMetric) {
                self.currentMetric = self.enabledMetrics[0]
            }
            self.refreshStatusItem(with: self.monitor.snapshot)
        }

        // Watch battery level for the low-battery screen-edge glow.
        GlowController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        rotationTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private var enabledMetrics: [MenuBarMetric] {
        let defaults = UserDefaults.standard
        let choices: [(MenuBarMetric, String)] = [
            (.watts, DefaultsKey.showMenuBarWatts),
            (.percent, DefaultsKey.showMenuBarPercent),
            (.time, DefaultsKey.showMenuBarTime)
        ]
        let enabled = choices.compactMap { metric, key in
            (defaults.object(forKey: key) as? Bool ?? true) ? metric : nil
        }
        return enabled.isEmpty ? [.watts] : enabled
    }

    private func advanceMetric() {
        let metrics = enabledMetrics
        if let index = metrics.firstIndex(of: currentMetric) {
            currentMetric = metrics[(index + 1) % metrics.count]
        } else {
            currentMetric = metrics[0]
        }
        refreshStatusItem(with: monitor.snapshot)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func refreshStatusItem(with snapshot: BatterySnapshot) {
        guard let button = statusItem?.button else { return }
        let defaults = UserDefaults.standard
        let glyph = BatteryGlyph(
            snapshot: snapshot,
            metric: currentMetric,
            darkMenuBar: button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
            warn: defaults.object(forKey: DefaultsKey.warnThreshold) as? Int ?? 20,
            critical: defaults.object(forKey: DefaultsKey.criticalThreshold) as? Int ?? 10
        )
        guard glyph.cacheKey != lastIconKey, let image = glyph.renderedImage() else { return }
        button.image = image
        lastIconKey = glyph.cacheKey
    }
}
