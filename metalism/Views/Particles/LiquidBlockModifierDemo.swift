//
//  LiquidBlockModifierDemo.swift
//  metalism
//
//  Demonstrates the liquidBlock shader on multiple regions of a scrolling
//  tile grid. Three layerEffect calls are chained on one canvas, each
//  targeting a different block region using absolute screen coordinates.
//

import SwiftUI

private struct LiquidModifierScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LiquidBlockModifierDemo: View {

    @State private var scrollOffset: CGFloat = 0

    private let tileSize: CGFloat = 80
    private let tileRows: Int     = 20
    private let hPadding: CGFloat = 16

    private let colours: [Color] = [
        .red, .black, .blue, .white
    ]

    var body: some View {
        GeometryReader { geo in
            let size       = geo.size
            let totalHeight = CGFloat(tileRows) * tileSize
            let blockWidth = size.width - hPadding * 2
            let cx         = Float(size.width / 2)

            // Block centreY positions
            let cy1 = Float(size.height * 0.25)
            let cy2 = Float(size.height * 0.50)
            let cy3 = Float(size.height * 0.75)

            ZStack {
                Color.black.ignoresSafeArea()

//                // ── Invisible ScrollView ──────────────────────────────────────
                ScrollView {
                    GeometryReader { inner in
                        Color.clear
                            .preference(
                                key: LiquidModifierScrollKey.self,
                                value: -inner.frame(in: .named("lbModifier")).minY
                            )
                    }
                    .frame(height: totalHeight)
                }
                .coordinateSpace(name: "lbModifier")
                .onPreferenceChange(LiquidModifierScrollKey.self) { scrollOffset = $0 }

                // ── Tile canvas with three chained block effects ───────────────
                Canvas { ctx, canvasSize in
                    let tileCols = Int(ceil(canvasSize.width / tileSize)) + 1
                    for row in 0..<tileRows {
                        for col in 0..<tileCols {
                            let x = CGFloat(col) * tileSize
                            let y = CGFloat(row) * tileSize - scrollOffset
                            guard y + tileSize > 0, y < canvasSize.height else { continue }
                            let colour = colours[(row * tileCols + col) % colours.count]
                            ctx.fill(
                                Path(CGRect(x: x, y: y,
                                            width: tileSize - 2, height: tileSize - 2)),
                                with: .color(colour.opacity(0.55))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                // Block 1 — wide bar
                .layerEffect(
                    ShaderLibrary.liquidBlock(
                        .float2(cx, cy1),
                        .float2(Float(blockWidth / 2), 40),
                        .float(16), .float(28)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )
                // Block 2 — card
                .layerEffect(
                    ShaderLibrary.liquidBlock(
                        .float2(cx, cy2),
                        .float2(Float(blockWidth / 2), 70),
                        .float(20), .float(32)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )
                // Block 3 — pill
                .layerEffect(
                    ShaderLibrary.liquidBlock(
                        .float2(cx, cy3),
                        .float2(Float(size.width * 0.275), 32),
                        .float(32), .float(20)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )

                // ── Stroke overlays ───────────────────────────────────────────
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: blockWidth, height: 80)
                    .position(x: size.width / 2, y: size.height * 0.25)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: blockWidth, height: 140)
                    .position(x: size.width / 2, y: size.height * 0.50)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: size.width * 0.55, height: 64)
                    .position(x: size.width / 2, y: size.height * 0.75)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LiquidBlockModifierDemo()
}
