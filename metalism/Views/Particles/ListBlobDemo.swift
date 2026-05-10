//
//  ListBlobDemo.swift
//  metalism
//
//  A scrollable word list with a plain circle blob fixed in the centre
//  of the screen, floating above the list content.
//

import SwiftUI

private struct ListBlobScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListBlobDemo: View {

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
    private let circleRadius: CGFloat = 90

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight

            ZStack {
                // ── Background ─────────────────────────────────────────────
                Color.black.ignoresSafeArea()

                // ── Invisible ScrollView — captures offset only ───────────
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ListBlobScrollKey.self,
                                value: -inner.frame(in: .named("listBlob")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listBlob")
                .onPreferenceChange(ListBlobScrollKey.self) { scrollOffset = $0 }

                // ── List canvas with blob-edge CA shader ──────────────────
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)

                Canvas { ctx, canvasSize in
                    // Dark background
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

                    // Separator lines + word rows
                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset

                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        ctx.draw(
                            Text(word)
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.65)),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)
                .layerEffect(
                    ShaderLibrary.blobEdge(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(circleRadius)),
                        .float(28.0)   // ring width in points
                    ),
                    maxSampleOffset: CGSize(width: 60, height: 60)
                )

                // ── Circle blob fixed at screen centre ─────────────────────
                Circle()
                    .fill(Color.white.opacity(0.0))
                    .overlay(
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                            Circle()
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1.5)
                                .scaleEffect(0.75)
                        }
                    )
                    .frame(width: circleRadius * 2, height: circleRadius * 2)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ListBlobDemo()
}
