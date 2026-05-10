//
//  LiquidBlockDemo.swift
//  metalism
//
//  Scrollable word list with a rounded-rectangle (corner radius 8) liquid
//  block overlay — height 100, full width minus 10 pt horizontal padding —
//  fixed at the centre of the screen.
//

import SwiftUI

private struct LiquidBlockScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LiquidBlockDemo: View {

    @State private var scrollOffset: CGFloat = 0

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM", "VORTEX",
        "SIGNAL", "VECTOR", "MOTION", "RIPPLE", "STATIC",
        "FATHOM", "ZENITH", "VERTEX", "RADIAL", "OBLIQUE",
        "FILTER", "WARP", "DISTORT", "REFRACT", "GLITCH",
        "PIXEL", "RENDER", "SHADER", "BUFFER", "DEPTH"
    ]

    private let rowHeight: CGFloat    = 56
    private let blockHeight: CGFloat  = 100
    private let hPadding: CGFloat     = 10
    private let cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let size        = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight
            let blockWidth  = size.width - hPadding * 2
            let centre      = CGPoint(x: size.width / 2, y: size.height / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                // ── Invisible ScrollView — captures offset only ───────────────
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: LiquidBlockScrollKey.self,
                                value: -inner.frame(in: .named("liquidBlock")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "liquidBlock")
                .onPreferenceChange(LiquidBlockScrollKey.self) { scrollOffset = $0 }

                // ── List canvas with liquid-block shader ─────────────────────
                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

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
                    ShaderLibrary.liquidBlock(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float2(Float(blockWidth / 2), Float(blockHeight / 2)),
                        .float(Float(cornerRadius)),
                        .float(28.0)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )

                // ── Rounded rect stroke overlay ───────────────────────────────
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
                    .frame(width: blockWidth, height: blockHeight)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LiquidBlockDemo()
}
