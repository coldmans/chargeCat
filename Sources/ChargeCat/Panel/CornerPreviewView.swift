import SwiftUI

struct CornerPreviewView: View {
    let side: ScreenSide
    let previewLevel: Double

    private var previewGIFSize: CGSize {
        GIFAsset.catDoor.previewDisplaySize
    }

    private var previewAlignment: Alignment {
        side == .left ? .bottomLeading : .bottomTrailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Corner Preview")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(Int(previewLevel.rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.cocoa)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.screen, Palette.screenEdge],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                VStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Circle().fill(Color.white.opacity(0.25)).frame(width: 10, height: 10)
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 10, height: 10)
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 10, height: 10)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 160, height: 18)
                        .padding(.bottom, 18)
                }

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)

                ZStack(alignment: previewAlignment) {
                    Ellipse()
                        .fill(Color.black.opacity(0.18))
                        .blur(radius: 10)
                        .frame(width: 74, height: 14)
                        .padding(.bottom, 18)
                        .padding(side == .left ? .leading : .trailing, 26)

                    GIFAnimationView(
                        asset: .catDoor,
                        frameIndex: GIFAsset.catDoor.previewFrame
                    )
                    .frame(width: previewGIFSize.width, height: previewGIFSize.height)
                    .scaleEffect(x: side == .left ? 1 : -1, y: 1)
                    .padding(.bottom, 18)
                    .padding(side == .left ? .leading : .trailing, 18)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .frame(height: 250)
            .shadow(color: Palette.shadow, radius: 24, x: 0, y: 14)
        }
    }
}
