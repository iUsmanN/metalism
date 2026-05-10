//
//  WaterDropletDemo.swift
//  metalism
//
//  Water droplets sitting on the screen. Each droplet is a convex lens:
//  it refracts the background content, with chromatic aberration and a
//  darkened rim. Droplets have a slow organic wobble over time.
//

import SwiftUI

struct WaterDropletDemo: View {

    private let startDate = Date()

    private let words = [
        "DROPLET", "REFRACT", "SURFACE", "LENS", "CRYSTAL",
        "RIPPLE", "REFLECT", "CAUSTIC", "CLEAR", "LIQUID",
        "BEAD", "MENISCUS", "PRISM", "DAMP", "FLOW",
        "GLOSS", "SHEEN", "AQUA", "POOL", "STREAM",
        "VAPOUR", "MIST", "HUMID", "WET", "SLICK",
        "OPTIC", "BEND", "FOCUS", "DIFFUSE", "SCATTER"
    ]

    private let rowHeight: CGFloat = 52

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size

                Canvas { ctx, canvasSize in
                    // Background: deep blue-grey, like a wet surface
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(Color(red: 0.06, green: 0.09, blue: 0.14))
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
                    ctx.stroke(gridPath, with: .color(Color.white.opacity(0.05)), lineWidth: 0.5)

                    // Word rows
                    for (i, word) in words.enumerated() {
                        let screenY = CGFloat(i) * rowHeight + rowHeight / 2
                        ctx.draw(
                            Text(word)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.5)),
                            at: CGPoint(x: canvasSize.width / 2, y: screenY),
                            anchor: .center
                        )
                    }
                }
                .layerEffect(
                    ShaderLibrary.waterDroplet(
                        .float2(Float(size.width), Float(size.height)),
                        .float(time)
                    ),
                    maxSampleOffset: CGSize(width: 50, height: 50)
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WaterDropletDemo()
}
