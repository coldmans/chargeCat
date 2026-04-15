import SwiftUI

struct PortalGlowView: View {
    let glow: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18 * glow),
                        Palette.amber.opacity(0.75 * glow),
                        Palette.coral.opacity(0.65 * glow)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22 * glow), lineWidth: 1)
            }
            .frame(width: 58, height: 88)
    }
}
