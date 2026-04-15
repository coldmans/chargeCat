import SwiftUI

struct ControlsSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Controls")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Picker("Side", selection: Binding(
                get: { model.preferredSide },
                set: { model.updatePreferredSide($0) }
            )) {
                ForEach(ScreenSide.allCases) { side in
                    Text(side.title).tag(side)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preview Battery")
                    Spacer()
                    Text("\(Int(model.previewBatteryLevel.rounded()))%")
                        .foregroundStyle(Palette.cocoa)
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)

                Slider(value: Binding(
                    get: { model.previewBatteryLevel },
                    set: { model.previewBatteryLevel = $0 }
                ), in: 1...100, step: 1)
                .tint(Palette.amber)
            }

            HStack(spacing: 12) {
                Button {
                    model.trigger(.chargeStarted)
                } label: {
                    Label("Play Charge Start", systemImage: "bolt.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    model.trigger(.fullyCharged, level: 100)
                } label: {
                    Label("Play Full Charge", systemImage: "sparkles")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            Toggle("Auto react to real charging events", isOn: Binding(
                get: { model.autoMonitorEnabled },
                set: { model.updateAutoMonitorEnabled($0) }
            ))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .disabled(model.batteryMonitoringAvailable == false)

            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.updateLaunchAtLogin($0) }
            ))
            .font(.system(size: 13, weight: .semibold, design: .rounded))

            if let launchAtLoginErrorMessage = model.launchAtLoginErrorMessage {
                Text(launchAtLoginErrorMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
    }
}
