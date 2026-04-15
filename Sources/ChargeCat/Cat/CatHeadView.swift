import SwiftUI

struct CatHeadView: View {
    let condition: CatCondition
    let expressions: CatExpressions
    let headTilt: Double

    var body: some View {
        Circle()
            .fill(Palette.amber)
            .frame(width: condition.headSize, height: condition.headSize)
            .overlay(alignment: .topLeading) {
                Triangle()
                    .fill(Palette.amber)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 2, y: condition.earLift)
            }
            .overlay(alignment: .topTrailing) {
                Triangle()
                    .fill(Palette.amber)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(12))
                    .offset(x: -2, y: condition.earLift)
            }
            .overlay {
                ZStack {
                    HStack(spacing: 10) {
                        eye
                        eye
                    }
                    .offset(y: -2)

                    Circle()
                        .fill(Palette.cocoa)
                        .frame(width: 4, height: 4)
                        .offset(y: 5)

                    SmileShape(curve: expressions.smileAmount, mouthOpen: expressions.mouthOpen)
                        .stroke(Palette.cocoa, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 18, height: 10 + expressions.mouthOpen * 10)
                        .offset(y: 9 + expressions.mouthOpen * 2)
                }
            }
            .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    private var eye: some View {
        Capsule()
            .fill(Palette.cocoa)
            .frame(width: expressions.eyeWidth, height: expressions.eyeHeight)
            .scaleEffect(x: 1, y: expressions.eyeScaleY, anchor: .center)
            .rotationEffect(.degrees(expressions.eyeRotation))
    }
}
