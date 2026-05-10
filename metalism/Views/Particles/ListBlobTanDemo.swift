//
//  ListBlobTanDemo.swift
//  metalism
//
//  Copy of ListBlobTextDemo using the tan-curve blob edge shader.
//  Refraction and distortion follow a U-shaped tan profile over the outer
//  20% ring: maximum at both the 80% and 100% diameter marks, reduced
//  at the midpoint of the ring (~90%).
//

import SwiftUI

private struct ListBlobTanScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListBlobTanDemo: View {

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
                                key: ListBlobTanScrollKey.self,
                                value: -inner.frame(in: .named("listBlobTan")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listBlobTan")
                .onPreferenceChange(ListBlobTanScrollKey.self) { scrollOffset = $0 }

                // ── List canvas with tan blob-edge shader ─────────────────
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                // ringWidth = outer 40% of radius (60% → 100%)
                let ringWidth = circleRadius * 0.4

                Canvas { ctx, canvasSize in
                    // Dark background
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

                    // Word rows
                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset

                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        // Pseudo-random hue per row
                        let hue = Double(i * 137 % 360) / 360.0
                        let textColor = Color(hue: hue, saturation: 0.65, brightness: 1.0)

                        ctx.draw(
                            Text(word)
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundStyle(textColor),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)
                .layerEffect(
                    ShaderLibrary.blobEdgeTan(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(circleRadius)),
                        .float(Float(ringWidth))
                    ),
                    maxSampleOffset: CGSize(width: 60, height: 60)
                )

                // ── Circle blob outline fixed at screen centre ─────────────
                Circle()
                    .fill(Color.white.opacity(0.0))
                    .overlay(
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                            Circle()
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1.5)
                                .scaleEffect(0.6)
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
    ListBlobTanDemo()
}
