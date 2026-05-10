//
//  ListBlobSquareDemo.swift
//  metalism
//
//  Copy of ListBlobDemo but uses a square instead of a circle.
//  The square has the same edge blur, refraction, warp and CA effects.
//

import SwiftUI

private struct ListBlobSquareScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListBlobSquareDemo: View {

    @State private var scrollOffset: CGFloat = 0

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM", "VORTEX",
        "SIGNAL", "VECTOR", "MOTION", "RIPPLE", "STATIC",
        "FATHOM", "ZENITH", "VERTEX", "RADIAL", "OBLIQUE",
        "FILTER", "WARP", "DISTORT", "REFRACT", "GLITCH",
        "PIXEL", "RENDER", "SHADER", "BUFFER", "DEPTH"
    ]

    private let rowHeight: CGFloat = 56
    private let halfSize: CGFloat = 90    // half side-length of the square

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight

            ZStack {
                Color.black.ignoresSafeArea()

                // Invisible ScrollView — captures offset only
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ListBlobSquareScrollKey.self,
                                value: -inner.frame(in: .named("listBlobSquare")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listBlobSquare")
                .onPreferenceChange(ListBlobSquareScrollKey.self) { scrollOffset = $0 }

                // List canvas with square blob-edge shader
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)

                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset

                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        var sep = Path()
                        sep.move(to: CGPoint(x: 16, y: screenY))
                        sep.addLine(to: CGPoint(x: canvasSize.width - 16, y: screenY))
                        ctx.stroke(sep, with: .color(.white.opacity(0.07)), lineWidth: 0.5)

                        ctx.draw(
                            Text(word)
                                .font(.system(size: 27, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.65)),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)
                .layerEffect(
                    ShaderLibrary.blobSquareEdge(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(halfSize)),
                        .float(28.0)
                    ),
                    maxSampleOffset: CGSize(width: 60, height: 60)
                )

                // Square overlay at screen centre
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                    )
                    .frame(width: halfSize * 2, height: halfSize * 2)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ListBlobSquareDemo()
}
