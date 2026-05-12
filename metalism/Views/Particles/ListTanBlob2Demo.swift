//
//  ListTanBlob2Demo.swift
//  metalism
//
//  Copy of ListBlobTanDemo using BlobEdgeTan2Shader.
//

import SwiftUI

private struct ListTanBlob2ScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ListTanBlob2Demo: View {

    @State private var scrollOffset: CGFloat = 0
    @State private var blurRadius: CGFloat = 28
    @State private var refractionStr: CGFloat = 0.54
    @State private var specularStr: CGFloat = 0.12
    @State private var causticStr: CGFloat = 0.25

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
                                key: ListTanBlob2ScrollKey.self,
                                value: -inner.frame(in: .named("listTanBlob2")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "listTanBlob2")
                .onPreferenceChange(ListTanBlob2ScrollKey.self) { scrollOffset = $0 }

                // ── List canvas with tan blob-edge shader ─────────────────
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let ringWidth = circleRadius * 0.4

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
                    ShaderLibrary.blobEdgeTan2(
                        .float2(Float(centre.x), Float(centre.y)),
                        .float(Float(circleRadius)),
                        .float(Float(ringWidth)),
                        .float(Float(scrollOffset)),
                        .float(Float(blurRadius)),
                        .float(Float(refractionStr)),
                        .float(Float(specularStr)),
                        .float(Float(causticStr))
                    ),
                    maxSampleOffset: CGSize(width: 120, height: 120)
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
        .overlay(alignment: .bottom) {
            VStack(spacing: 2) {
                sliderRow("Blur", value: $blurRadius, in: 0...120, format: "\(Int(blurRadius))px")
                sliderRow("Refraction", value: $refractionStr, in: 0...3, format: String(format: "%.2f", refractionStr))
                sliderRow("Specular", value: $specularStr, in: 0...3, format: String(format: "%.2f", specularStr))
                sliderRow("Caustic", value: $causticStr, in: 0...3, format: String(format: "%.2f", causticStr))
            }
            .padding(.bottom, 40)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ListTanBlob2Demo()
}
