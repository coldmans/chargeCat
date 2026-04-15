import SwiftUI

struct DoorSceneView: View {
    let condition: CatCondition
    let doorAngle: Double
    let catTravel: CGFloat
    let bowAngle: Double
    let smileAmount: CGFloat
    let mouthOpen: CGFloat
    let squint: CGFloat
    let headTilt: Double
    let bodyScaleY: CGFloat
    let bounce: CGFloat
    let portalGlow: Double
    let sparkleOpacity: Double
    let sparkleScale: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Ellipse()
                .fill(Palette.shadow.opacity(0.35))
                .blur(radius: 12)
                .frame(width: 124, height: 24)
                .offset(x: 38, y: 8)

            PortalGlowView(glow: portalGlow)
                .offset(x: 22, y: -8)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.cocoa)
                .frame(width: 64, height: 94)
                .offset(x: 18, y: -10)

            DoorPanelView(angle: doorAngle)
                .offset(x: 23, y: -8)

            sparkleCluster
                .opacity(sparkleOpacity)
                .scaleEffect(sparkleScale)
                .offset(x: 92, y: -78)

            CatCharacterView(
                condition: condition,
                smileAmount: smileAmount,
                mouthOpen: mouthOpen,
                squint: squint,
                bowAngle: bowAngle,
                headTilt: headTilt,
                bodyScaleY: bodyScaleY
            )
            .offset(x: 22 + catTravel, y: bounce - 10)
        }
    }

    private var sparkleCluster: some View {
        ZStack {
            SparkleShape().fill(Color.white.opacity(0.9)).frame(width: 12, height: 12)
            SparkleShape().fill(Palette.cream).frame(width: 9, height: 9).offset(x: -20, y: 10)
            SparkleShape().fill(Palette.peach).frame(width: 8, height: 8).offset(x: 14, y: 16)
            SparkleShape().fill(Palette.amber).frame(width: 7, height: 7).offset(x: 8, y: -14)
        }
    }
}
