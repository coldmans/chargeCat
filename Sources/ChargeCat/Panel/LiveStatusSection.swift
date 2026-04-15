import SwiftUI

struct LiveStatusSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Status")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            if let latestBattery = model.latestBattery {
                HStack(spacing: 10) {
                    StatusBadge(
                        text: latestBattery.powerText,
                        tint: latestBattery.isPluggedIn ? Palette.amber : Palette.coral
                    )
                    StatusBadge(text: "\(latestBattery.level)%", tint: Palette.cocoa)
                    StatusBadge(text: model.currentPowerMode.title, tint: Palette.ink)
                }
            } else {
                Text("No battery data detected yet. Preview buttons still work.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                StatusBadge(text: model.currentPowerMode.title, tint: Palette.ink)
            }

            Text(model.lastEventDescription)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}
