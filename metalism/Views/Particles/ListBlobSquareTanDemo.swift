//
//  ListBlobSquareTanDemo.swift
//  metalism
//
//  Copy of ListBlobTanDemo using a square shape (Chebyshev distance)
//  via BlobSquareEdgeTanShader.
//

import SwiftUI

private struct ListBlobSquareTanScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListBlobSquareTanDemo: View {

    @State private var scrollOffset: CGFloat = 0
    @State private var blurRadius: CGFloat = 1

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
                // ── Background ─────────────────────────────────────────────
                Color.black.ignoresSafeArea()

                // ── Invisible ScrollView — captures offset only ───────────
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ListBlobSquareTanScrollKey.self,
                                value: -inner.frame(in: .named("listBlobSquareTan")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listBlobSquareTan")
                .onPreferenceChange(ListBlobSquareTanScrollKey.self) { scrollOffset = $0 }

                // ── List canvas with square tan blob-edge shader ───────────
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let ringWidth = halfSize          // full 0–100% interior

                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset
                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

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
                    ShaderLibrary.blobSquareEdgeTan(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(halfSize)),
                        .float(Float(ringWidth)),
                        .float(Float(scrollOffset)),
                        .float(Float(blurRadius))
                    ),
                    maxSampleOffset: CGSize(width: 120, height: 120)
                )

                // ── Square outline fixed at screen centre ──────────────────
                Rectangle()
                    .fill(Color.clear)
                    .overlay(
                        ZStack {
                            Rectangle()
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                            Rectangle()
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1.5)
                                .scaleEffect(0.6)
                        }
                    )
                    .frame(width: halfSize * 2, height: halfSize * 2)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text("Blur: \(Int(blurRadius))px")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                Slider(value: $blurRadius, in: 0...120, step: 1)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ListBlobSquareTanDemo()
}
