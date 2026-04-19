import SwiftUI

struct ProSection: View {
    let model: AppModel

    @State private var showsActivationTools = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.copy.proSectionTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                header
                purchaseHero

                if model.licenseConfiguration.isConfigured == false {
                    NoticeBanner(
                        icon: "gear.badge.xmark",
                        text: model.copy.proNotConfigured,
                        tint: Palette.amber
                    )
                }

                if model.licenseWarningText.isEmpty == false {
                    NoticeBanner(
                        icon: "wifi.exclamationmark",
                        text: model.licenseWarningText,
                        tint: Palette.amber
                    )
                }

                if let infoMessage = model.licenseInfoMessage {
                    NoticeBanner(
                        icon: "checkmark.circle.fill",
                        text: infoMessage,
                        tint: Palette.amber
                    )
                }

                if let errorMessage = model.licenseErrorMessage {
                    NoticeBanner(
                        icon: "exclamationmark.triangle.fill",
                        text: errorMessage,
                        tint: Palette.coral
                    )
                }

                activationTools

                HStack(spacing: 10) {
                    LinkChip(title: model.copy.myOrders, systemImage: "bag") {
                        model.openMyOrders()
                    }
                    LinkChip(title: model.copy.support, systemImage: "lifepreserver") {
                        model.openSupport()
                    }
                }

                if model.hasStoredLicense {
                    Divider().background(Palette.ink.opacity(0.05))

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await model.refreshLicense(force: true, reason: "manual refresh", showsProgress: true)
                            }
                        } label: {
                            Label(model.copy.refreshLicense, systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(model.isLicenseBusy)

                        Button {
                            Task {
                                await model.deactivateCurrentMac()
                            }
                        } label: {
                            Label(model.copy.deactivateThisMac, systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(model.isLicenseBusy)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        DetailRow(label: model.copy.status, value: model.copy.title(for: model.licenseState.status))
                        DetailRow(label: model.copy.savedKey, value: model.maskedLicenseKey ?? model.copy.noneOnThisMac)
                        DetailRow(label: model.copy.receiptEmail, value: model.licenseState.customerEmail ?? model.copy.notSaved)
                        DetailRow(label: model.copy.lastVerified, value: model.licenseLastValidatedText)
                        DetailRow(label: model.copy.lastAttempt, value: model.licenseLastAttemptText)
                        DetailRow(label: model.copy.nextRetry, value: model.licenseNextRetryText)
                    }
                }

                if model.isLicenseBusy, let licenseActivityText = model.licenseActivityText {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(licenseActivityText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.65))
                    }
                } else {
                    Text(model.copy.proFooter)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .shadow(color: Palette.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .task {
            if model.hasStoredLicense || model.licenseState.hasProAccess || model.licenseKeyDraft.isEmpty == false {
                showsActivationTools = true
            }
            await model.refreshLicense(force: false, reason: "settings", showsProgress: false)
        }
        .onChange(of: model.hasStoredLicense) { _, hasStoredLicense in
            if hasStoredLicense {
                showsActivationTools = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: model.licenseState.status.systemImage)
                .foregroundStyle(model.licenseState.status.allowsProAccess ? Palette.amber : Palette.coral)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.copy.title(for: model.licenseState.status))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Text(model.licenseSummaryText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var purchaseHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.copy.proHeroTitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text(model.copy.proHeroSubtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await model.startUpgradeToPro()
                }
            } label: {
                Label(model.copy.proPrimaryCTA, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(model.isLicenseBusy || model.canStartProCheckout == false)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Palette.amber.opacity(0.22), Palette.peach.opacity(0.2), Color.white.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.amber.opacity(0.2), lineWidth: 1)
        )
    }

    private var activationTools: some View {
        DisclosureGroup(
            isExpanded: $showsActivationTools,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.copy.activatePurchasedPro)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)

                        Text(model.copy.activatePurchasedProSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 10) {
                        SecureField(model.copy.licenseKeyPlaceholder, text: Binding(
                            get: { model.licenseKeyDraft },
                            set: { model.licenseKeyDraft = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
                        )

                        TextField(model.copy.receiptEmailOptional, text: Binding(
                            get: { model.customerEmailDraft },
                            set: { model.customerEmailDraft = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
                        )
                    }

                    Button {
                        Task {
                            await model.activateLicense()
                        }
                    } label: {
                        Label(model.copy.activateLicense, systemImage: "key.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(model.isLicenseBusy || model.licenseKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            },
            label: {
                HStack(spacing: 8) {
                    Image(systemName: "key.horizontal.fill")
                        .foregroundStyle(Palette.coral)
                    Text(model.copy.alreadyPurchased)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
            }
        )
        .tint(Palette.ink)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .frame(width: 86, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NoticeBanner: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LinkChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.9), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
