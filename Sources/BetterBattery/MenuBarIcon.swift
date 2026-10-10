import SwiftUI
import AppKit

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case watts
    case percent
    case time

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watts: return "전력"
        case .percent: return "배터리 잔량"
        case .time: return "남은 시간"
        }
    }

    var example: String {
        switch self {
        case .watts: return "26W"
        case .percent: return "85%"
        case .time: return "1h30m"
        }
    }

    var symbol: String {
        switch self {
        case .watts: return "bolt.fill"
        case .percent: return "battery.100"
        case .time: return "clock"
        }
    }
}

/// Flat, modern battery glyph modeled on the iOS status bar battery:
/// translucent capsule track, solid fill sized to the charge level, and the
/// reading (percent / time / watts) drawn in contrasting colors on the filled
/// and empty portions of the battery.
///
/// The glyph is drawn offscreen into an image before it reaches the menu
/// bar so the text and fill stay consistent in the AppKit status item.
struct BatteryGlyph: View {
    let snapshot: BatterySnapshot
    let metric: MenuBarMetric
    let darkMenuBar: Bool
    let warn: Int
    let critical: Int

    private let bodyHeight: CGFloat = 13
    private let cornerRadius: CGFloat = 4
    // One fixed size for every display mode so the menu bar never shifts.
    private let bodyWidth: CGFloat = 36

    private var baseColor: Color { darkMenuBar ? .white : .black }

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseColor.opacity(0.35))

                Rectangle()
                    .fill(fillColor)
                    .frame(width: fillWidth)

                readoutOverlay
                    .foregroundStyle(filledTextColor)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: fillWidth)
                    }

                readoutOverlay
                    .foregroundStyle(baseColor)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .mask(alignment: .trailing) {
                        Rectangle().frame(width: bodyWidth - fillWidth)
                    }
            }
            .frame(width: bodyWidth, height: bodyHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // the nub
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(baseColor.opacity(0.5))
                .frame(width: 2, height: 4.5)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 1)
    }

    // MARK: - Pieces

    private var readoutOverlay: some View {
        Text(readout ?? "")
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }

    private var readout: String? {
        guard snapshot.state != .noBattery else { return nil }
        switch metric {
        case .percent:
            return "\(snapshot.percent)%"
        case .watts:
            let magnitude = abs(snapshot.smoothedWatts)
            if magnitude < 0.05 { return "0W" }
            let number = magnitude >= 10
                ? String(format: "%.0f", magnitude)
                : String(format: "%.1f", magnitude)
            switch snapshot.state {
            case .charging:
                return "▴\(number)W"
            case .discharging:
                return "▾\(number)W"
            default:
                return "\(number)W"
            }
        case .time:
            let minutes: Int?
            switch snapshot.state {
            case .charging: minutes = snapshot.timeToFullMinutes
            case .discharging: minutes = snapshot.timeToEmptyMinutes
            case .charged: return "완료"
            case .pluggedIdle: return "대기"
            case .noBattery: return nil
            }
            guard let minutes else { return "–" }
            let hours = minutes / 60
            let mins = minutes % 60
            if hours > 0 { return String(format: "%dh%02dm", hours, mins) }
            return "\(mins)m"
        }
    }

    private var fillWidth: CGFloat {
        guard snapshot.state != .noBattery else { return 0 }
        let fraction = max(0, min(1, Double(snapshot.percent) / 100))
        return max(4, bodyWidth * CGFloat(fraction))
    }

    private var fillColor: Color {
        PowerAccent.iconFill(for: snapshot, warn: warn, critical: critical, neutral: baseColor)
    }

    private var filledTextColor: Color {
        // Black exceeds 6:1 contrast on every colored fill, including red.
        // A neutral fill uses the opposite of the menu bar's foreground color.
        if snapshot.state == .discharging && snapshot.percent > warn {
            return darkMenuBar ? .black : .white
        }
        return .black
    }

    /// Everything that affects the rendered pixels, cheap to compare —
    /// The status item uses this to skip re-rendering identical frames.
    var cacheKey: String {
        "\(metric.rawValue)|\(readout ?? "")|\(snapshot.percent)|\(String(describing: snapshot.state))|\(darkMenuBar)|\(warn)|\(critical)"
    }

    func renderedImage() -> NSImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = max(2, NSScreen.main?.backingScaleFactor ?? 2)
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
