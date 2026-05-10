//
//  RainbowListDemo.swift
//  metalism
//
//  30 rows of words in a scrollable Canvas with a Metal layerEffect
//  that pixelates the bottom 30% of the view.
//

import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RainbowListDemo: View {

    private let startDate = Date()
    @State private var scrollOffset: CGFloat = 0

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM", "VORTEX",
        "SIGNAL", "VECTOR", "MOTION", "RIPPLE", "STATIC",
        "FATHOM", "ZENITH", "VERTEX", "RADIAL", "OBLIQUE",
        "FILTER", "WARP", "DISTORT", "REFRACT", "GLITCH",
        "PIXEL", "RENDER", "SHADER", "BUFFER", "DEPTH"
    ]

    private let rowHeight: CGFloat = 52

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size
                let totalHeight = CGFloat(words.count) * rowHeight

                // Invisible ScrollView just to capture scroll offset
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: -inner.frame(in: .named("scroll")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }

                // Single Canvas overlay — only renderer, shader applied here
                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(.black)
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset

                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        // Separator line at top of each row
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: screenY))
                        line.addLine(to: CGPoint(x: canvasSize.width, y: screenY))
//                        ctx.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 0.5)

                        ctx.draw(
                            Text(word)
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.7)),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)
                .layerEffect(
                    ShaderLibrary.pixelateBottom(
                        .float2(Float(size.width), Float(size.height)),
                        .float(time)
                    ),
                    maxSampleOffset: CGSize(width: 60, height: 0)
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    RainbowListDemo()
}
