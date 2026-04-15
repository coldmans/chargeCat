import SwiftUI

struct CatBodyView: View {
    let condition: CatCondition
    let scaleY: CGFloat

    var body: some View {
        Ellipse()
            .fill(Palette.amber)
            .frame(width: condition.bodySize.width, height: condition.bodySize.height)
            .overlay {
                Ellipse()
                    .fill(Palette.peach.opacity(0.85))
                    .frame(
                        width: condition.bodySize.width * 0.66,
                        height: condition.bodySize.height * 0.56
                    )
                    .offset(y: 5)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Capsule().fill(Palette.cocoa).frame(width: 12, height: 8)
                    Capsule().fill(Palette.cocoa).frame(width: 12, height: 8)
                }
                .offset(x: 12, y: 5)
            }
            .scaleEffect(x: 1, y: scaleY, anchor: .bottom)
    }
}
