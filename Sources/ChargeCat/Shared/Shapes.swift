import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SmileShape: Shape {
    let curve: CGFloat
    let mouthOpen: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = mouthOpen * 1.8
        path.move(to: CGPoint(x: rect.minX, y: rect.midY - curve * 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - curve * 2),
            control: CGPoint(x: rect.midX, y: rect.maxY + curve * 18 + inset * 8)
        )

        if mouthOpen > 0.12 {
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY + 2))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 2, y: rect.midY + 2),
                control: CGPoint(x: rect.midX, y: rect.maxY + mouthOpen * 20)
            )
        }

        return path
    }
}

struct CatTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 8))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 4, y: rect.minY + 8),
            control1: CGPoint(x: rect.minX + 10, y: rect.midY),
            control2: CGPoint(x: rect.maxX - 6, y: rect.midY - 12)
        )
        return path
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: midY - rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: midX + rect.width * 0.14, y: midY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: midY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: midX - rect.width * 0.14, y: midY - rect.height * 0.14))
        path.closeSubpath()
        return path
    }
}
