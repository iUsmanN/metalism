//
//  ListBlobBinaryDemo.swift
//  metalism
//
//  Variation of ListTanBlob2Demo where the ring region renders the underlying
//  content as binary 0s and 1s based on pixel luminance.
//  A Cutoff slider controls the luma threshold and a Contrast slider controls
//  how sharply pixels are classified as 0 or 1.
//

import SwiftUI

private struct ListBlobBinaryScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListBlobBinaryDemo: View {

    @State private var scrollOffset: CGFloat = 0
    @State private var cutoff:       CGFloat = 0.45
    @State private var contrast:     CGFloat = 8.0

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM", "VORTEX",
        "SIGNAL", "VECTOR", "MOTION", "RIPPLE", "STATIC",
        "FATHOM", "ZENITH", "VERTEX", "RADIAL", "OBLIQUE",
        "FILTER", "WARP", "DISTORT", "REFRACT", "GLITCH",
        "PIXEL", "RENDER", "SHADER", "BUFFER", "DEPTH"
    ]

    private let rowHeight:    CGFloat = 56
    private let circleRadius: CGFloat = 90

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        HStack {
            Text("\(label): \(format)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 140, alignment: .leading)
            Slider(value: value, in: range)
        }
        .padding(.horizontal)
    }

    var body: some View {
        GeometryReader { geo in
            let size        = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight

            ZStack {
                // ── Background ─────────────────────────────────────────────
                Color.black.ignoresSafeArea()

                // ── Invisible ScrollView — captures offset only ─────────
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ListBlobBinaryScrollKey.self,
                                value: -inner.frame(in: .named("listBlobBinary")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listBlobBinary")
                .onPreferenceChange(ListBlobBinaryScrollKey.self) { scrollOffset = $0 }

                // ── Scrolling word list ─────────────────────────────────
                let centre    = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = circleRadius * 1.05
                let ringWidth   = circleRadius * 0.5

                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.07))
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset
                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        let hue       = Double(i * 137 % 360) / 360.0
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
                    ShaderLibrary.blobBinary(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(outerRadius)),
                        .float(Float(ringWidth)),
                        .float(Float(cutoff)),
                        .float(Float(contrast)),
                        .float(Float(scrollOffset))
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )

                // ── Ring outline ──────────────────────────────────────────
                Circle()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 2) {
                sliderRow("Cutoff",   value: $cutoff,   in: 0...1,    format: String(format: "%.2f", cutoff))
                sliderRow("Contrast", value: $contrast, in: 1...30,   format: String(format: "%.1f", contrast))
            }
            .padding(.bottom, 40)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ListBlobBinaryDemo()
}
