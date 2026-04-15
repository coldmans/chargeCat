import SwiftUI

struct DoorPanelView: View {
    let angle: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.amber.opacity(0.9), Palette.coral.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Circle()
                    .fill(Palette.cream)
                    .frame(width: 6, height: 6)
                    .offset(x: 15)
            }
            .frame(width: 54, height: 82)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.75
            )
    }
}
