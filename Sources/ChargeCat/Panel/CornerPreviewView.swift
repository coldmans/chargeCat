import SwiftUI

struct CornerPreviewView: View {
    let language: AppLanguage
    let side: ScreenSide
    let asset: OverlayAnimationAsset
    @Binding var previewLevel: Double

    private var previewMediaSize: CGSize {
        asset.previewDisplaySize
    }

    private var previewAlignment: Alignment {
        side == .left ? .bottomLeading : .bottomTrailing
    }

    private var shadowWidth: CGFloat {
        max(previewMediaSize.width * 0.48, 74)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(AppCopy(language: language).cornerPreview)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(Int(previewLevel.rounded()))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.cocoa)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.cocoa.opacity(0.1), in: Capsule())
            }

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.screen, Palette.screenEdge],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
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

                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                        .frame(width: shadowWidth, height: 14)
                        .padding(.bottom, 18)
                        .padding(side == .left ? .leading : .trailing, 26)

                    previewMediaView
                    .frame(width: previewMediaSize.width, height: previewMediaSize.height)
                    .scaleEffect(x: side == .left ? 1 : -1, y: 1)
                    .padding(.bottom, 18)
                    .padding(side == .left ? .leading : .trailing, 18)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .frame(height: 220)
            .shadow(color: Palette.shadow.opacity(0.06), radius: 16, x: 0, y: 8)
            
            Slider(value: $previewLevel, in: 1...100, step: 1)
                .tint(Palette.amber)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var previewMediaView: some View {
        if let gifAsset = asset.gifAsset {
            GIFAnimationView(
                asset: gifAsset,
                frameIndex: gifAsset.previewFrame
            )
        } else if let videoAsset = asset.videoAsset {
            VideoAnimationView(
                asset: videoAsset,
                loop: true,
                isMuted: true,
                playbackID: asset.rawValue
            )
        }
    }
}
