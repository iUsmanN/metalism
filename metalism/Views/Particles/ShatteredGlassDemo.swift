//
//  ShatteredGlassDemo.swift
//  metalism
//
//  Shattered glass effect: a Voronoi tessellation divides the screen into
//  glass shards. Near each shard edge the view is refracted with chromatic
//  aberration. Fragment size is adjustable via a slider.
//

import SwiftUI

struct ShatteredGlassDemo: View {

    // Fragment scale: low = few large shards, high = many small shards
    @State private var fragmentScale: Float = 5.0  // range 0.5–10

    private let words = [
        "SHATTER", "REFRACT", "PRISM", "CRYSTAL", "FRACTURE",
        "REFLECT", "CAUSTIC", "FRAGMENT", "MIRROR", "SHARD",
        "CLARITY", "SCATTER", "DIFFUSE", "TRANSMIT", "DISTORT",
        "WARP", "LENS", "FOCAL", "SPLINTER", "CRACK",
        "BREAK", "OPAQUE", "LUSTER", "FACET", "DEPTH",
        "RENDER", "SHADER", "BUFFER", "PIXEL", "VECTOR"
    ]

    private let rowHeight: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .bottom) {
                Canvas { ctx, canvasSize in
                    // Dark charcoal background
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(white: 0.08))
                    )

                    // Subtle grid
                    let gridStep: CGFloat = 52
                    var gridPath = Path()
                    var x: CGFloat = 0
                    while x <= canvasSize.width {
                        gridPath.move(to: CGPoint(x: x, y: 0))
                        gridPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
                        x += gridStep
                    }
                    var y: CGFloat = 0
                    while y <= canvasSize.height {
                        gridPath.move(to: CGPoint(x: 0, y: y))
                        gridPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
                        y += gridStep
                    }
                    ctx.stroke(gridPath, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)

                    // Word rows
                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight + rowHeight / 2
                        ctx.draw(
                            Text(word)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55)),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY),
                            anchor: .center
                        )
                    }
                }
                .layerEffect(
                    ShaderLibrary.shatteredGlass(
                        .float2(Float(size.width), Float(size.height)),
                        .float(fragmentScale)
                    ),
                    maxSampleOffset: CGSize(width: 50, height: 50)
                )

                // Slider control
                VStack(spacing: 6) {
                    Text("Fragment size")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    HStack {
                        Text("Large")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Slider(value: $fragmentScale, in: 0.5...20, step: 0.5)
                            .tint(.white)
                        Text("Small")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ShatteredGlassDemo()
}
