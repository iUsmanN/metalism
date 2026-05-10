//
//  TapGlowDemo.swift
//  metalism
//
//  Tap anywhere on the canvas. A Metal shader renders a radial brightness
//  glow centred exactly on the tap point — maximum brightness at centre,
//  smoothly fading to zero at the edge. The glow pulses in then fades out.
//

import SwiftUI

struct TapGlowDemo: View {

    @State private var tapLocation: CGPoint = .zero
    @State private var glowStrength: Float  = 0
    @State private var isGlowing: Bool      = false

    private let glowRadius: Float = 160

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            sceneCanvas(size: size)
                .layerEffect(
                    ShaderLibrary.tapGlow(
                        .float2(Float(tapLocation.x), Float(tapLocation.y)),
                        .float(glowRadius),
                        .float(glowStrength)
                    ),
                    maxSampleOffset: CGSize(width: Double(glowRadius * 0.22),
                                           height: Double(glowRadius * 0.22))
                )
                .contentShape(Rectangle())
                .onTapGesture { location in
                    tapLocation  = location
                    glowStrength = 0

                    // Pulse in
                    withAnimation(.easeOut(duration: 0.15)) {
                        glowStrength = 1.0
                    }
                    // Then fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.6)) {
                            glowStrength = 0
                        }
                    }
                }
        }
        .ignoresSafeArea()
    }

    // MARK: - Scene content drawn in a pure-SwiftUI Canvas

    private func sceneCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            // Dark background
            ctx.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(Color(red: 0.07, green: 0.07, blue: 0.12))
            )

            // Grid
            let step: CGFloat = 44
            var grid = Path()
            var x: CGFloat = 0
            while x <= canvasSize.width  { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: canvasSize.height)); x += step }
            var y: CGFloat = 0
            while y <= canvasSize.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: canvasSize.width, y: y)); y += step }
            ctx.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 0.5)

            // Scattered filled circles for visual richness
            let palette: [Color] = [
                Color(red: 0.4, green: 0.6, blue: 1.0),
                Color(red: 0.9, green: 0.4, blue: 0.6),
                Color(red: 0.4, green: 0.9, blue: 0.7),
                Color(red: 1.0, green: 0.75, blue: 0.3),
                Color(red: 0.7, green: 0.4, blue: 1.0),
            ]

            var rng = SeededRNG(seed: 42)
            for _ in 0..<28 {
                let cx = rng.next() * canvasSize.width
                let cy = rng.next() * canvasSize.height
                let r  = 10 + rng.next() * 28
                let c  = palette[Int(rng.next() * CGFloat(palette.count)) % palette.count]
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(c.opacity(0.55))
                )
            }

            // Tap hint text at centre if no tap yet
            ctx.draw(
                Text("Tap anywhere")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.3)),
                at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                anchor: .center
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Minimal deterministic RNG for consistent circle placement
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
}

#Preview {
    TapGlowDemo()
}
