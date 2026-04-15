import SwiftUI

struct OnboardingView: View {
    let model: AppModel
    let onStart: () -> Void

    @State private var launchAtLoginEnabled = UserSettings.launchAtLoginEnabled

    private var onboardingGIFSize: CGSize {
        GIFAsset.catDoor.onboardingDisplaySize
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.paper, Palette.cream, .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                GIFAnimationView(
                    asset: .catDoor,
                    frameIndex: GIFAsset.catDoor.onboardingFrame
                )
                .frame(width: onboardingGIFSize.width, height: onboardingGIFSize.height)

                Text("Charge Cat is ready.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Text("Plug in your Mac and a tiny cat will step out to say hello.")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.72))
                    .multilineTextAlignment(.center)

                Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .toggleStyle(.switch)
                    .padding(.top, 4)

                Button("Get Started") {
                    model.completeOnboarding(launchAtLoginEnabled: launchAtLoginEnabled)
                    onStart()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .frame(maxWidth: 220)
            }
            .padding(32)
            .frame(width: 420)
        }
    }
}
