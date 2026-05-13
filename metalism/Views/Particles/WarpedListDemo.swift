//
//  WarpedListDemo.swift
//  metalism
//

import SwiftUI

private struct WarpedListScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WarpedListDemo: View {

    @State private var scrollOffset: CGFloat = 0

    private let warpAmt: Float = 1.2
    private let saturation: Float = 0.8

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM",  "VORTEX",
        "SIGNAL",  "VECTOR", "MOTION", "RIPPLE",  "STATIC",
        "FATHOM",  "ZENITH", "VERTEX", "RADIAL",  "OBLIQUE"
    ]

    private let rowHeight: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight

            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                // Invisible ScrollView — drives scrollOffset only
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: WarpedListScrollKey.self,
                                value: -inner.frame(in: .named("warpedList")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "warpedList")
                .onPreferenceChange(WarpedListScrollKey.self) { scrollOffset = $0 }

                // Canvas renders the list rows and receives the shader
                Canvas { ctx, canvasSize in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(uiColor: .systemBackground))
                    )

                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight - scrollOffset
                        guard screenY + rowHeight > 0, screenY < canvasSize.height else { continue }

                        let hue = Double(i * 137 % 360) / 360.0
                        ctx.draw(
                            Text(word)
                                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(hue: hue, saturation: 0.7, brightness: 1.0)),
                            at: CGPoint(x: 20, y: screenY + rowHeight / 2),
                            anchor: .leading
                        )

                        let divY = screenY + rowHeight - 0.5
                        ctx.fill(
                            Path(CGRect(x: 0, y: divY, width: canvasSize.width, height: 0.5)),
                            with: .color(Color.primary.opacity(0.1))
                        )
                    }
                }
                .layerEffect(
                    ShaderLibrary.verticalStretch(
                        .float2(Float(size.width), Float(size.height)),
                        .float(warpAmt),
                        .float(saturation)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: 60)
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Warped List")
    }
}

#Preview {
    NavigationStack {
        WarpedListDemo()
    }
}
