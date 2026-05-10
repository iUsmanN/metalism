//
//  RadialShatterDemo.swift
//  metalism
//
//  Tap anywhere to trigger a radial shattered-glass effect that grows
//  outward from the tap point. Fragments are finest at the impact and
//  grow in size as the wave expands.
//

import SwiftUI

struct RadialShatterDemo: View {

    @State private var impactPoint: CGPoint = .zero
    @State private var strength: Float = 0.0
    @State private var waveRadius: Float = 0.0
    @State private var isAnimating: Bool = false
    @State private var hasEverTapped: Bool = false

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
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAnimating)) { _ in
            GeometryReader { geo in
                let size = geo.size

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
                    ShaderLibrary.radialShatter(
                        .float2(Float(size.width), Float(size.height)),
                        .float2(Float(impactPoint.x), Float(impactPoint.y)),
                        .float(strength),
                        .float(waveRadius)
                    ),
                    maxSampleOffset: CGSize(width: 50, height: 50)
                )
                .contentShape(Rectangle())
                .onTapGesture { location in
                    impactPoint = location
                    triggerShatter()
                }

                if !hasEverTapped {
                    Text("Tap anywhere to shatter")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func triggerShatter() {
        hasEverTapped = true
        isAnimating = true
        strength = 1.0
        waveRadius = 0.0

        // Expand the wave radius outward; once it fully covers the screen
        // push waveRadius to a very large value so all pixels are included
        // and the effect stays permanently.
        withAnimation(.easeOut(duration: 0.6)) {
            waveRadius = 1.6   // large enough to cover any corner
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            // Lock in the full effect: no trailing edge, no fade
            waveRadius = 99.0
            isAnimating = false
        }
    }
}

#Preview {
    RadialShatterDemo()
}
