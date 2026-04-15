import SwiftUI

struct CatTailView: View {
    var body: some View {
        CatTailShape()
            .stroke(
                Palette.cocoa,
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 42, height: 62)
    }
}
