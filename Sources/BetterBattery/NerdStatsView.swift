import SwiftUI

/// The fun version of the details readout: a grid of live mini-tiles with
/// gauges, a spinning fan, and the lifetime-energy party trick.
struct NerdStatsView: View {
    @ObservedObject var monitor: PowerMonitor

    /// Average U.S. home usage ≈ 10,500 kWh/yr ≈ 1.2 kWh per hour (EIA).
    private static let homeWhPerHour = 1200.0
    /// Nominal MacBook battery pack voltage, for the pre-app energy estimate.
    private static let nominalPackVoltage = 11.4

    var body: some View {
        let snap = monitor.snapshot
        VStack(spacing: 6) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 6
            ) {
                temperatureTile(snap)
                if let fans = monitor.fans, !fans.isEmpty {
                    fansTile(fans)
                }
                electricalTile(snap)
                healthTile(snap)
                sessionTile
                adapterTile(snap)
            }
            capacityTile(snap)
            lifetimeTile(snap)
        }
    }

    private var sessionTile: some View {
        let hours = monitor.sessionDischargeSeconds / 3600
        let average = hours > 0.01 ? monitor.sessionDischargeWh / hours : 0
        return tile(icon: "hourglass", tint: .purple, title: "이번 사용") {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.1f Wh", monitor.sessionDischargeWh))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(average > 0 ? String(format: "평균 사용 %.1f W", average) : "배터리 사용 기록 없음")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func adapterTile(_ snap: BatterySnapshot) -> some View {
        tile(icon: "powerplug", tint: PowerAccent.green, title: "어댑터") {
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.adapterWatts.map { "\($0) W" } ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(snap.adapterWatts != nil ? "연결됨" : "연결 안 됨")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tiles

    private func temperatureTile(_ snap: BatterySnapshot) -> some View {
        tile(icon: "thermometer", tint: PowerAccent.orange, title: "온도") {
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.4), value: snap.temperatureC)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [PowerAccent.blue, PowerAccent.orange, PowerAccent.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * tempFraction(snap))
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func tempFraction(_ snap: BatterySnapshot) -> CGFloat {
        guard let temperature = snap.temperatureC else { return 0 }
        return CGFloat(min(1, max(0.05, (temperature - 10) / 40)))   // 10–50 °C scale
    }

    private func fansTile(_ fans: [FanReading]) -> some View {
        tile(icon: "fanblades", tint: PowerAccent.blue, title: "팬") {
            HStack(spacing: 6) {
                if let maxRpm = fans.map(\.rpm).max(), maxRpm > 50 {
                    SpinningFanIcon(rpm: maxRpm)
                    Text(fans.map { String(format: "%.0f", $0.rpm) }.joined(separator: " · ") + " rpm")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Image(systemName: "fanblades")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("꺼짐")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func electricalTile(_ snap: BatterySnapshot) -> some View {
        tile(icon: "bolt.fill", tint: Color.yellow, title: "전압 · 전류") {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.2f V", snap.voltage))
                Text(String(format: "%.2f A", snap.amperage))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
        }
    }

    private func healthTile(_ snap: BatterySnapshot) -> some View {
        let health = snap.healthPercent
        let tint: Color = {
            guard let health else { return .secondary }
            if health >= 88 { return PowerAccent.green }
            if health >= 80 { return PowerAccent.orange }
            return PowerAccent.red
        }()
        return tile(icon: "heart.fill", tint: tint, title: "배터리 성능") {
            VStack(alignment: .leading, spacing: 1) {
                Text(health.map { "\($0)%" } ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(snap.cycleCount.map { "사이클 \($0)회" } ?? "사이클 —")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func capacityTile(_ snap: BatterySnapshot) -> some View {
        tile(icon: "battery.100", tint: PowerAccent.blue, title: "용량") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(snap.rawCurrentmAh.map(String.init) ?? "—") / \(snap.rawFullmAh.map(String.init) ?? "—") mAh")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    if let design = snap.designmAh {
                        Text("설계 \(design)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.10))
                        if let current = snap.rawCurrentmAh, let full = snap.rawFullmAh, full > 0 {
                            Capsule()
                                .fill(PowerAccent.blue)
                                .frame(width: geo.size.width * CGFloat(min(1, Double(current) / Double(full))))
                        }
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func lifetimeTile(_ snap: BatterySnapshot) -> some View {
        let measured = monitor.lifetimeDischargeWh
        let estimated = estimatedPreAppWh(snap)
        let total = measured + estimated
        let homeHours = total / Self.homeWhPerHour
        return tile(icon: "bolt.batteryblock.fill", tint: PowerAccent.green, title: "누적 사용 전력량 (추정)") {
            VStack(alignment: .leading, spacing: 3) {
                Text(energyText(total))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PowerAccent.green)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text("미국 평균 가정의 \(homeTimeText(homeHours)) 사용량")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(String(format: "사이클 기준 추정 %.0f Wh · 앱 측정 %.1f Wh", estimated, measured))
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func tile<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.09))
        )
    }

    /// Energy cycled before this app was installed: each cycle is one full
    /// discharge of (roughly) the design capacity at nominal pack voltage.
    private func estimatedPreAppWh(_ snap: BatterySnapshot) -> Double {
        guard let cycles = snap.cycleCount, let design = snap.designmAh else { return 0 }
        return Double(cycles) * Double(design) / 1000.0 * Self.nominalPackVoltage
    }

    private func energyText(_ wh: Double) -> String {
        wh >= 1000 ? String(format: "≈ %.2f kWh", wh / 1000) : String(format: "≈ %.0f Wh", wh)
    }

    private func homeTimeText(_ hours: Double) -> String {
        if hours >= 48 { return String(format: "약 %.1f일", hours / 24) }
        if hours >= 1 { return String(format: "약 %.1f시간", hours) }
        return String(format: "약 %.0f분", hours * 60)
    }
}

/// The `fanblades` glyph, turning continuously while the fans are spinning.
///
/// Deliberately *not* a `TimelineView`: that schedule needs SwiftUI to
/// re-evaluate the view every frame, and it never ticks inside the
/// `MenuBarExtra(.window)` panel. The icon therefore only redrew when
/// `PowerMonitor` published — once a second — so it jumped a whole second of
/// rotation at a time instead of spinning.
///
/// A `repeatForever` rotation is handed to the render server once and then
/// runs without waking SwiftUI per frame, which keeps the open panel smooth
/// and costs nothing while it is closed (this view isn't rendered at all).
private struct SpinningFanIcon: View {
    let rpm: Double

    @State private var angle: Double = 0

    /// Seconds per revolution: a lazy turn when the fans are just ticking
    /// over, brisker under load, and never quick enough to strobe against the
    /// glyph's blades.
    private var period: Double {
        let raw = min(3.0, max(0.8, 3600 / max(rpm, 1)))
        // Quantise, so ordinary rpm jitter (2400 → 2408) doesn't restart the
        // animation. Only a real change in fan speed re-syncs the spin.
        return (raw / 0.25).rounded() * 0.25
    }

    var body: some View {
        Image(systemName: "fanblades")
            .font(.system(size: 15))
            .foregroundStyle(PowerAccent.blue)
            .rotationEffect(.degrees(angle))
            // Runs on appear and again whenever the quantised speed changes.
            .task(id: period) {
                // A full turn ends where it began, so each repeat is seamless.
                withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                    angle += 360
                }
            }
    }
}
