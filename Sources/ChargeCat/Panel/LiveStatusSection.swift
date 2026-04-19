import SwiftUI

struct LiveStatusSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Status")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                if let latestBattery = model.latestBattery {
                    HStack(spacing: 8) {
                        StatusBadge(
                            icon: latestBattery.isPluggedIn ? "bolt.fill" : "battery.50",
                            text: latestBattery.powerText,
                            tint: latestBattery.isPluggedIn ? Palette.amber : Palette.coral
                        )
                        StatusBadge(
                            icon: "percent",
                            text: "\(latestBattery.level)%",
                            tint: Palette.cocoa
                        )
                        StatusBadge(
                            icon: "powerplug",
                            text: model.currentPowerMode.title,
                            tint: Palette.ink
                        )
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.amber)
                        Text("No battery data detected yet.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    .padding(.vertical, 4)

                    StatusBadge(
                        icon: "powerplug",
                        text: model.currentPowerMode.title,
                        tint: Palette.ink
                    )
                }

                Divider().background(Palette.ink.opacity(0.05))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Palette.ink.opacity(0.4))
                        .padding(.top, 2)
                    Text(model.lastEventDescription)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .shadow(color: Palette.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }
}

private struct StatusBadge: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .foregroundStyle(tint)
    }
}
