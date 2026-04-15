import SwiftUI

struct ControlPanelView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.paper, Palette.cream, .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                CornerPreviewView(side: model.preferredSide, previewLevel: model.previewBatteryLevel)
                ControlsSection(model: model)
                LiveStatusSection(model: model)
                Spacer(minLength: 0)
            }
            .padding(28)
        }
        .frame(width: 460, height: 640)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("v1.0")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.ink.opacity(0.08), in: Capsule())

                Text("Charge Cat")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }

            Text("A tiny ritual for the moment your Mac starts charging.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.72))

            Text("Pick a corner, tune the mood, and preview the cat before the next real power event.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.coral)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
