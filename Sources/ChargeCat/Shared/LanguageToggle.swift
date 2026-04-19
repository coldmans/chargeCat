import SwiftUI

struct LanguageToggle: View {
    let currentLanguage: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    onSelect(language)
                } label: {
                    Text(language.shortLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(currentLanguage == language ? Color.white : Palette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    currentLanguage == language
                                        ? LinearGradient(
                                            colors: [Palette.amber, Palette.coral],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.92), Color.white.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    currentLanguage == language ? Color.white.opacity(0.4) : Palette.ink.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
