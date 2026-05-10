//
//  RainbowListBlurDemo.swift
//  metalism
//
//  Copy of RainbowListDemo with a directional horizontal blur added to
//  the bottom zone. Blur intensity scales with the stretch amount.
//

import SwiftUI

private struct ScrollOffsetKeyBlur: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RainbowListBlurDemo: View {

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

                // Invisible ScrollView to capture scroll offset
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKeyBlur.self,
                                value: -inner.frame(in: .named("scrollBlur")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "scrollBlur")
                .onPreferenceChange(ScrollOffsetKeyBlur.self) { scrollOffset = $0 }

                // Single Canvas with stretchBlur shader
                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(.black)
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset

                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

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
                    ShaderLibrary.stretchBlur(
                        .float2(Float(size.width), Float(size.height)),
                        .float(time)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 0)
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    RainbowListBlurDemo()
}
