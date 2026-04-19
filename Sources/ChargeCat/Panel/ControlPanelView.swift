import SwiftUI

struct ControlPanelView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            // Background
            ZStack {
                LinearGradient(
                    colors: [Palette.paper, Palette.cream, Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Circle()
                    .fill(Palette.peach.opacity(0.4))
                    .blur(radius: 80)
                    .frame(width: 300, height: 300)
                    .offset(x: -150, y: -250)

                Circle()
                    .fill(Palette.amber.opacity(0.25))
                    .blur(radius: 100)
                    .frame(width: 350, height: 350)
                    .offset(x: 200, y: 300)
            }

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        CornerPreviewView(
                            side: model.preferredSide,
                            asset: model.selectedAnimationAsset,
                            previewLevel: Binding(
                                get: { model.previewBatteryLevel },
                                set: { model.previewBatteryLevel = $0 }
                            )
                        )
                        ControlsSection(model: model)
                        LiveStatusSection(model: model)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(width: 460, height: 740)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("v1.0")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.ink.opacity(0.08), in: Capsule())

                Text("Charge Cat")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }

            Text("A tiny ritual for the moment your Mac starts charging.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.72))

            Text("Pick a corner, tune the mood, and preview the cat before the next real power event.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.coral)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}
