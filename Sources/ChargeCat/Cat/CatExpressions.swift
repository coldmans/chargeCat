import CoreGraphics

struct CatExpressions {
    let smileAmount: CGFloat
    let mouthOpen: CGFloat
    let eyeWidth: CGFloat
    let eyeHeight: CGFloat
    let eyeRotation: Double
    let eyeScaleY: CGFloat

    static func make(
        condition: CatCondition,
        smileAmount: CGFloat,
        mouthOpen: CGFloat,
        squint: CGFloat
    ) -> CatExpressions {
        let baseWidth: CGFloat = condition == .low ? 7 : 6
        let baseHeight: CGFloat = condition == .low ? 2 : 4
        return CatExpressions(
            smileAmount: smileAmount,
            mouthOpen: mouthOpen,
            eyeWidth: baseWidth,
            eyeHeight: max(1.2, baseHeight * max(0.3, 1 - squint)),
            eyeRotation: condition == .low ? -12 : 0,
            eyeScaleY: max(0.4, 1 - squint)
        )
    }
}
