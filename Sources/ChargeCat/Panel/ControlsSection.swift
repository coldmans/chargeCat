import SwiftUI

struct ControlsSection: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.copy.settings)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text(model.copy.animation)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                    } icon: {
                        Image(systemName: "film")
                            .foregroundStyle(Palette.amber)
                    }

                    Text(model.copy.animationByEvent)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.62))

                    AnimationAssignmentRow(model: model, event: .chargeStarted)
                    AnimationAssignmentRow(model: model, event: .fullyCharged)

                    if model.canCustomizeAnimations == false {
                        Text(model.copy.proAnimationCustomizationLocked)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider().background(Palette.ink.opacity(0.05))

                    AnimationDownloadsSection(model: model)
                }
                .task {
                    await model.refreshDownloadableAssets(showsProgress: false)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)

                Divider().background(Palette.ink.opacity(0.05))

                // Corner Selection
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(model.copy.screenCorner)
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
                                    title: model.copy.title(for: side),
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
                            Text(model.copy.testCharge)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        model.trigger(.fullyCharged, level: 100)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(model.copy.testFull)
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
                            Text(model.copy.autoReactToRealCharging)
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
                            Text(model.copy.launchAtLogin)
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

private struct AnimationAssignmentRow: View {
    let model: AppModel
    let event: OverlayEventKind

    private var selectedReference: OverlayAssetReference {
        model.assetReference(for: event)
    }

    private var selectedAsset: InstalledOverlayAsset {
        model.resolvedAsset(for: event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.copy.title(for: event))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)

                    Text(model.assignedAssetTitle(for: event))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }

                Spacer()

                Text(selectedAsset.isDownloaded ? model.copy.installedBadge : model.copy.bundledBadge)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }

            if model.canCustomizeAnimations {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.installedOverlayAssets) { asset in
                            Button {
                                model.updateAnimationAssignment(for: event, to: asset.reference)
                            } label: {
                                SelectionChip(
                                    title: model.displayTitle(for: asset),
                                    systemImage: asset.systemImage,
                                    isSelected: selectedReference == asset.reference
                                )
                                .frame(minWidth: 138)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct AnimationDownloadsSection: View {
    let model: AppModel

    private var installedDownloadedAssets: [InstalledOverlayAsset] {
        model.installedOverlayAssets.filter(\.isDownloaded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(model.copy.downloadableAnimations)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Palette.amber)
                }

                Spacer()

                Button {
                    Task { await model.refreshDownloadableAssets(showsProgress: true) }
                } label: {
                    Label(model.copy.refreshCatalog, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.7))
            }

            if let message = model.assetLibraryInfoMessage {
                InlineMessage(text: message, tint: Palette.amber)
            }

            if let message = model.assetLibraryErrorMessage {
                InlineMessage(text: message, tint: Palette.coral)
            }

            if let activity = model.assetLibraryActivityText {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text(activity)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
            }

            if model.hasAssetCatalog == false {
                Text(model.copy.downloadableAssetsNotConfigured)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            } else if model.downloadableAssetCatalog.isEmpty {
                Text(model.copy.noDownloadableAnimationsYet)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            } else {
                VStack(spacing: 10) {
                    ForEach(model.downloadableAssetCatalog) { asset in
                        DownloadableAssetRow(model: model, asset: asset)
                    }
                }
            }

            if installedDownloadedAssets.isEmpty == false {
                Divider().background(Palette.ink.opacity(0.05))

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(installedDownloadedAssets) { asset in
                        HStack(spacing: 10) {
                            Label {
                                Text(model.displayTitle(for: asset))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.ink)
                            } icon: {
                                Image(systemName: asset.systemImage)
                                    .foregroundStyle(Palette.amber)
                            }

                            Spacer()

                            Button(model.copy.delete) {
                                Task { await model.deleteOverlayAsset(asset) }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.coral)
                            .disabled(model.deletingAssetIDs.contains(asset.id))
                        }
                    }
                }
            }
        }
    }
}

private struct DownloadableAssetRow: View {
    let model: AppModel
    let asset: OverlayAssetCatalogEntry

    private var isInstalled: Bool {
        model.installedOverlayAssets.contains { $0.reference == OverlayAssetReference(source: .downloaded, value: asset.id) }
    }

    private var isDownloading: Bool {
        model.downloadingAssetIDs.contains(asset.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: asset.systemImage ?? "square.and.arrow.down")
                        .foregroundStyle(Palette.amber)
                    Text(asset.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }

                if let recommendedEvent = asset.recommendedEvent {
                    Text(model.copy.title(for: recommendedEvent))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                }
            }

            Spacer()

            if isInstalled {
                Text(model.copy.installedBadge)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.85), in: Capsule())
            } else {
                Button(isDownloading ? "..." : model.copy.download) {
                    Task { await model.downloadOverlayAsset(asset) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(model.canManageDownloadableAssets ? Palette.amber : Palette.ink.opacity(0.4))
                .disabled(model.canManageDownloadableAssets == false || isDownloading)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct InlineMessage: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ChargeTargetRow: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(model.copy.fullChargeTarget)
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

            Slider(
                value: Binding(
                    get: { Double(model.chargeTargetLevel) },
                    set: { model.updateChargeTargetLevel(Int($0)) }
                ),
                in: Double(ChargeTarget.minimum)...Double(ChargeTarget.maximum),
                step: Double(ChargeTarget.step)
            )
            .tint(Palette.amber)

            Text(model.copy.catWillCheer(at: model.chargeTargetLevel))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.55))
        }
    }
}
