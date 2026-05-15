//
//  WarpedListDemo.swift
//  metalism
//

import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct WarpedListDemo: View {

    @State private var scrollOffset: CGFloat = 0

    private let warpAmt: Float = 1.2
    private let saturation: Float = 0.8

    private let images: [(name: String, aspectRatio: CGFloat)] = [
        ("1", 4000 / 2660),
        ("2", 3000 / 2002),
        ("3", 4000 / 2811),
        ("4", 4096 / 3112),
        ("5", 3840 / 2400),
        ("6", 7798 / 5201),
    ]

    private func layout(width: CGFloat) -> [(y: CGFloat, height: CGFloat)] {
        var result: [(CGFloat, CGFloat)] = []
        var y: CGFloat = 0
        for img in images {
            let h = width / img.aspectRatio
            result.append((y, h))
            y += h
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let items = layout(width: size.width)
            let totalHeight = items.last.map { $0.y + $0.height } ?? size.height

            ZStack {
                // Invisible scroll view — only drives scrollOffset
                ScrollView {
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -inner.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }

                // Canvas with images as symbols — resolved once, drawn each frame
                Canvas { ctx, canvasSize in
                    for (i, img) in images.enumerated() {
                        let (originY, height) = items[i]
                        let screenY = originY - scrollOffset
                        guard screenY + height > 0, screenY < canvasSize.height else { continue }

                        if let symbol = ctx.resolveSymbol(id: img.name) {
                            let rect = CGRect(x: 0, y: screenY,
                                             width: canvasSize.width, height: height)
                            ctx.drawLayer { child in
                                child.clip(to: Path(rect))
                                child.draw(symbol, in: rect)
                            }
                        }
                    }
                } symbols: {
                    // Each image pre-rendered at correct size — SwiftUI caches these
                    ForEach(images, id: \.name) { img in
                        Image(img.name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width,
                                   height: size.width / img.aspectRatio)
                            .clipped()
                            .tag(img.name)
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
