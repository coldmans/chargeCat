import SwiftUI

struct ControlsSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Animation")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                    } icon: {
                        Image(systemName: "film")
                            .foregroundStyle(Palette.amber)
                    }

                    HStack(spacing: 10) {
                        ForEach(OverlayAnimationAsset.allCases) { asset in
                            Button {
                                model.updateSelectedAnimationAsset(asset)
                            } label: {
                                SelectionChip(
                                    title: asset.title,
                                    systemImage: asset.systemImage,
                                    isSelected: model.selectedAnimationAsset == asset
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)

                Divider().background(Palette.ink.opacity(0.05))

                // Corner Selection
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Screen Corner")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                    } icon: {
                        Image(systemName: "macwindow")
                            .foregroundStyle(Palette.amber)
                    }

                    HStack(spacing: 10) {
                        ForEach(ScreenSide.allCases) { side in
                            Button {
                                model.updatePreferredSide(side)
                            } label: {
                                SelectionChip(
                                    title: side.title,
                                    systemImage: side == .left ? "sidebar.left" : "sidebar.right",
                                    isSelected: model.preferredSide == side
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                
                Divider().background(Palette.ink.opacity(0.05))

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        model.trigger(.chargeStarted)
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Test Charge")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        model.trigger(.fullyCharged, level: 100)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Test Full")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                
                Divider().background(Palette.ink.opacity(0.05))

                ChargeTargetRow(model: model)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)

                Divider().background(Palette.ink.opacity(0.05))

                // Toggles
                VStack(spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { model.autoMonitorEnabled },
                        set: { model.updateAutoMonitorEnabled($0) }
                    )) {
                        Label {
                            Text("Auto-react to real charging")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                        } icon: {
                            Image(systemName: "bolt.badge.a")
                                .foregroundStyle(Palette.amber)
                        }
                    }
                    .tint(Palette.amber)
                    .disabled(model.batteryMonitoringAvailable == false)

                    Toggle(isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.updateLaunchAtLogin($0) }
                    )) {
                        Label {
                            Text("Launch at Login")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                        } icon: {
                            Image(systemName: "macwindow.badge.plus")
                                .foregroundStyle(Palette.amber)
                        }
                    }
                    .tint(Palette.amber)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                
                if let error = model.launchAtLoginErrorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.coral)
                        .padding(.bottom, 14)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .shadow(color: Palette.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .toggleStyle(.switch)
    }
}

private struct SelectionChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(isSelected ? Color.white : Palette.ink)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(background)
        .overlay(border)
        .shadow(color: isSelected ? Palette.shadow.opacity(0.18) : .clear, radius: 10, x: 0, y: 6)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                    ? LinearGradient(
                        colors: [Palette.amber, Palette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? Color.white.opacity(0.4) : Palette.ink.opacity(0.08), lineWidth: 1)
    }
}

private struct ChargeTargetRow: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("Full Charge Target")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                } icon: {
                    Image(systemName: "battery.100.bolt")
                        .foregroundStyle(Palette.amber)
                }
                Spacer()
                Text("\(model.effectiveChargeTarget)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.amber)
                    .monospacedDigit()
            }

            Toggle(isOn: Binding(
                get: { model.chargeTargetFollowsSystem },
                set: { model.updateChargeTargetFollowsSystem($0) }
            )) {
                Text(systemToggleLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
            .toggleStyle(.switch)
            .tint(Palette.amber)

            if model.chargeTargetFollowsSystem == false {
                Slider(
                    value: Binding(
                        get: { Double(model.chargeTargetLevel) },
                        set: { model.updateChargeTargetLevel(Int($0)) }
                    ),
                    in: Double(ChargeTarget.minimum)...Double(ChargeTarget.maximum),
                    step: Double(ChargeTarget.step)
                )
                .tint(Palette.amber)

                Text("Cat will cheer at \(model.chargeTargetLevel)%.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            } else if model.systemChargeLimit == nil {
                Text("Couldn't read the system limit — falling back to 100%.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
        }
    }

    private var systemToggleLabel: String {
        if let limit = model.systemChargeLimit {
            return "Follow macOS setting (\(limit)%)"
        }
        return "Follow macOS setting"
    }
}
