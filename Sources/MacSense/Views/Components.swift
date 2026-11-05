import SwiftUI
import MacSenseCore
import Charts

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    var tint: Color = Palette.blue
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 14, weight: .semibold))
                Text(L10n.translate(title)).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                if let subtitle { Text(L10n.translate(subtitle)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1) }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
    }
}
struct MetricRing: View {
    let value: Double?
    var label = ""
    var tint = Palette.blue
    var size: CGFloat = 110
    var body: some View {
        ZStack {
            Circle().stroke(Palette.inset, lineWidth: 9)
            if let value {
                Circle().trim(from: 0, to: max(0, min(1, value / 100)))
                    .stroke(tint.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 4) {
                Text(Fmt.percent(value)).font(.system(size: size * 0.23, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(L10n.translate(label)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
        }.frame(width: size, height: size).padding(5)
        .accessibilityElement(children: .ignore).accessibilityLabel("\(label), \(Fmt.percent(value))")
    }
}
struct Sparkline: View {
    let points: [MetricPoint]
    var tint = Palette.blue
    var ceiling: Double? = 100
    var height: CGFloat = 54
    var body: some View {
        Group {
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 3).fill(Palette.inset)
                    .overlay(Text(L("Собираем историю…")).font(.system(size: 10)).foregroundStyle(.tertiary))
            } else {
                Chart(points) { point in
                    AreaMark(x: .value(L("Время"), point.date), y: .value(L("Значение"), point.value))
                        .foregroundStyle(LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0.015)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.linear)
                    LineMark(x: .value(L("Время"), point.date), y: .value(L("Значение"), point.value))
                        .foregroundStyle(tint).lineStyle(StrokeStyle(lineWidth: 1.6)).interpolationMethod(.linear)
                }
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .chartYScale(domain: 0...max(ceiling ?? (points.map(\.value).max() ?? 1) * 1.15, 1))
            }
        }.frame(height: height).accessibilityHidden(true)
    }
}
struct Meter: View {
    let value: Double
    var tint = Palette.blue
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.inset)
                Capsule().fill(tint.gradient).frame(width: geometry.size.width * max(0, min(1, value / 100)))
            }
        }.frame(height: height)
    }
}
struct DetailRow: View {
    let title: String
    let value: String
    var tint: Color? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.translate(title)).foregroundStyle(.secondary)
            Spacer(minLength: 15)
            Text(L10n.translate(value)).foregroundStyle(tint ?? .primary).multilineTextAlignment(.trailing).textSelection(.enabled)
        }.font(.system(size: 12)).padding(.vertical, 3)
    }
}
struct LegendRow: View {
    let title: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 7, height: 7)
            Text(L10n.translate(title)).foregroundStyle(.secondary)
            Spacer()
            Text(L10n.translate(value)).monospacedDigit()
        }.font(.system(size: 11))
    }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    let description: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.translate(eyebrow).uppercased()).font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.blue)
            Text(L10n.translate(title)).font(.system(size: 29, weight: .semibold))
            Text(L10n.translate(description)).font(.system(size: 12)).foregroundStyle(.secondary)
        }.padding(.bottom, 12)
    }
}
struct InfoNote: View {
    let text: String
    var icon = "info.circle"
    var body: some View {
        Label { Text(L10n.translate(text)).font(.system(size: 12)).lineSpacing(4) } icon: { Image(systemName: icon).foregroundStyle(Palette.blue) }
            .foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.blue.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct EmptyState: View {
    let icon: String
    let title: String
    let text: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 36, weight: .light)).foregroundStyle(.tertiary)
            Text(L10n.translate(title)).font(.system(size: 16, weight: .semibold))
            Text(L10n.translate(text)).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 430)
        }.padding(40).frame(maxWidth: .infinity)
    }
}
