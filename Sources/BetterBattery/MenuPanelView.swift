import SwiftUI
import AppKit
import ServiceManagement

/// Collapsible section header chip — the panel's shared design language.
struct SectionHeader: View {
    let icon: String
    let title: String
    let tint: [Color]   // one color = solid, two = gradient
    @Binding var expanded: Bool

    private var colors: [Color] {
        tint.count >= 2 ? tint : [tint.first ?? .gray, tint.first ?? .gray]
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 0 : -90))
            }
            .foregroundStyle(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            )
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.12) },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct MenuPanelView: View {
    @ObservedObject var monitor: PowerMonitor
    @AppStorage(DefaultsKey.showMenuBarWatts) private var showMenuBarWatts = true
    @AppStorage(DefaultsKey.showMenuBarPercent) private var showMenuBarPercent = true
    @AppStorage(DefaultsKey.showMenuBarTime) private var showMenuBarTime = true
    @AppStorage(DefaultsKey.warnThreshold) private var warnThreshold = 20
    @AppStorage(DefaultsKey.criticalThreshold) private var criticalThreshold = 10
    @AppStorage(DefaultsKey.lowBatteryGlow) private var lowBatteryGlow = true
    @AppStorage(DefaultsKey.glowWidth) private var glowWidth = 1.0
    @AppStorage(DefaultsKey.plugInCelebration) private var plugInCelebration = true
    @AppStorage(DefaultsKey.historyMode) private var historyModeRaw = HistoryMode.charge.rawValue
    @AppStorage(DefaultsKey.showNerdStats) private var showNerdStats = false
    @AppStorage(DefaultsKey.showSettingsSection) private var showSettingsSection = false
    @AppStorage(DefaultsKey.showLowBatterySection) private var showLowBatterySection = false
    @State private var launchAtLogin = false

    // SMAppService needs a real bundle; hide the toggle under `swift run`.
    private var canManageLoginItem: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private var selectedMetricCount: Int {
        [showMenuBarWatts, showMenuBarPercent, showMenuBarTime].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Zone 1 — hero glance
            WidgetContent(monitor: monitor)

            Divider()

            // Zone 2 — history
            HistoryChart(monitor: monitor, modeRaw: $historyModeRaw)

            Divider()

            // Zone 3 — collapsible sections, one chip language
            VStack(alignment: .leading, spacing: 6) {
                settingsSection
                lowBatterySection
                nerdSection
            }

            Divider()

            // Zone 4 — local build footer.
            footer
        }
        .padding(14)
        .frame(width: 324)
        .onAppear {
            if canManageLoginItem {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            // Migrate stored thresholds into the 1–20 band (older versions
            // allowed up to 50 in steps of 5).
            if warnThreshold > 20 { warnThreshold = 20 }
            if warnThreshold < 2 { warnThreshold = 2 }
            if criticalThreshold >= warnThreshold { criticalThreshold = max(1, warnThreshold - 1) }
            if criticalThreshold < 1 { criticalThreshold = 1 }
        }
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "gearshape.fill", title: "설정", tint: [.gray], expanded: $showSettingsSection)

            if showSettingsSection {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("메뉴 막대에 표시")
                            .font(.caption.weight(.semibold))
                        metricRow(.watts, isOn: $showMenuBarWatts)
                        metricRow(.percent, isOn: $showMenuBarPercent)
                        metricRow(.time, isOn: $showMenuBarTime)
                        Text("선택한 항목을 위 순서대로 2초마다 표시합니다. 하나만 선택하면 고정됩니다.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if canManageLoginItem {
                        Toggle("로그인 시 실행", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .onChange(of: launchAtLogin) { enabled in
                                updateLoginItem(enabled)
                            }
                    }

                    Button("충전 제한 및 배터리 설정…") {
                        openBatterySettings()
                    }
                    .controlSize(.mini)
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Low battery

    @ViewBuilder
    private var lowBatterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "battery.25", title: "배터리 부족", tint: [PowerAccent.orange], expanded: $showLowBatterySection)

            if showLowBatterySection {
                VStack(alignment: .leading, spacing: 6) {
                    thresholdRow(label: "경고", color: PowerAccent.orange, value: $warnThreshold, range: 2...20)
                    thresholdRow(label: "위험", color: PowerAccent.red, value: $criticalThreshold, range: 1...19)
                    Toggle("배터리 부족 시 화면 가장자리 알림", isOn: $lowBatteryGlow)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    if lowBatteryGlow {
                        HStack(spacing: 8) {
                            Text("알림 밝기")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $glowWidth, in: 0.5...2.0)
                                .controlSize(.mini)
                        }
                    }
                    Toggle("전원 연결 시 효과", isOn: $plugInCelebration)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    HStack(spacing: 6) {
                        Text("미리 보기")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("경고") { GlowController.shared.test(.warning) }
                        Button("위험") { GlowController.shared.test(.critical) }
                        Button("연결") { GlowController.shared.test(.plugged) }
                        Spacer()
                        Text("Esc로 종료")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .controlSize(.mini)
                }
                .padding(.leading, 4)
                .onChange(of: warnThreshold) { newValue in
                    if criticalThreshold >= newValue { criticalThreshold = max(1, newValue - 1) }
                }
                .onChange(of: criticalThreshold) { newValue in
                    if newValue >= warnThreshold { warnThreshold = min(20, newValue + 1) }
                }
            }
        }
    }

    // MARK: - Stats for Nerds

    @ViewBuilder
    private var nerdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                icon: "atom",
                title: "상세 정보",
                tint: [PowerAccent.blue, PowerAccent.green],
                expanded: $showNerdStats
            )

            if showNerdStats && monitor.snapshot.state != .noBattery {
                NerdStatsView(monitor: monitor)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            Text("배터리 전력 · 한국어판")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .keyboardShortcut("q")
        }
    }

    // MARK: - Helpers

    private func metricRow(_ metric: MenuBarMetric, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: metric.symbol)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(metric.label)
                .font(.caption)
            Spacer()
            Text(metric.example)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Toggle(metric.label, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(isOn.wrappedValue && selectedMetricCount == 1)
        }
    }

    private func thresholdRow(label: String, color: Color, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(label) · \(value.wrappedValue)%")
                .font(.caption)
            Spacer()
            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
                .controlSize(.mini)
        }
    }

    private func openBatterySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.battery"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
