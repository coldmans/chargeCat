import SwiftUI

struct CatCharacterView: View {
    let condition: CatCondition
    let smileAmount: CGFloat
    let mouthOpen: CGFloat
    let squint: CGFloat
    let bowAngle: Double
    let headTilt: Double
    let bodyScaleY: CGFloat

    var body: some View {
        let expressions = CatExpressions.make(
            condition: condition,
            smileAmount: smileAmount,
            mouthOpen: mouthOpen,
            squint: squint
        )

        ZStack(alignment: .bottomLeading) {
            CatTailView()
                .offset(x: 48, y: -16)

            CatBodyView(condition: condition, scaleY: bodyScaleY)

            CatHeadView(
                condition: condition,
                expressions: expressions,
                headTilt: headTilt
            )
            .offset(x: 10, y: -26)
        }
        .frame(width: 120, height: 100, alignment: .bottomLeading)
        .rotationEffect(.degrees(bowAngle), anchor: .bottomLeading)
    }
}
