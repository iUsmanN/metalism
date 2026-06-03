//
//  FullScreenBinaryCoverDemo.swift
//  metalism
//
//  Demonstrates FullScreenBinaryCoverModifier applied to a full-screen canvas.
//

import SwiftUI

private struct FullScreenBinaryCoverScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FullScreenBinaryCoverDemo: View {

    @State private var scrollOffset: CGFloat = 0
    @State private var effectEnabled: Bool   = true
    @State private var tappedIndex:   Int?   = nil

    private let words = [
        "HORIZON", "REFLECT", "MIRAGE", "CRYSTAL", "SHADOW",
        "FRACTAL", "AURORA", "CASCADE", "PRISM", "VORTEX",
        "SIGNAL", "VECTOR", "MOTION", "RIPPLE", "STATIC",
        "FATHOM", "ZENITH", "VERTEX", "RADIAL", "OBLIQUE",
        "FILTER", "WARP", "DISTORT", "REFRACT", "GLITCH",
        "PIXEL", "RENDER", "SHADER", "BUFFER", "DEPTH"
    ]

    private let rowHeight: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                    let hue      = Double(i * 137 % 360) / 360.0
                    let isActive = effectEnabled && tappedIndex != i
                    Text(word)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .frame(height: rowHeight)
                        .fullScreenBinaryCover(isEnabled: isActive, saturation: 0.0)
                        .onTapGesture {
                            tappedIndex = (tappedIndex == i) ? nil : i
                        }
                }
            }
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Effect", isOn: $effectEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
    
    var body2: some View {
        GeometryReader { geo in
            let size        = geo.size
            let totalHeight = CGFloat(words.count) * rowHeight

            ZStack {
                Color.black.ignoresSafeArea()

                // Invisible ScrollView — captures scroll offset only
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: FullScreenBinaryCoverScrollKey.self,
                                value: -inner.frame(in: .named("fullScreenBinaryCover")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "fullScreenBinaryCover")
                .onPreferenceChange(FullScreenBinaryCoverScrollKey.self) { scrollOffset = $0 }

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
                                .font(.system(size: 30, weight: .black, design: .monospaced))
                                .foregroundStyle(.white),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)
                .fullScreenBinaryCover(isEnabled: effectEnabled)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Full Screen Binary Cover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Effect", isOn: $effectEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    NavigationStack {
        FullScreenBinaryCoverDemo()
    }
}
