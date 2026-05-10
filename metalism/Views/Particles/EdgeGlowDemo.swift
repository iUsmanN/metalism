//
//  EdgeGlowDemo.swift
//  metalism
//
//  Tap anywhere. A ripple ring expands outward from the tap point, carrying
//  blur + chromatic aberration at its wavefront. Intensity fades as it grows.
//  Both radius and strength are driven from a single elapsed-time clock
//  to avoid animation glitches.
//

import SwiftUI

struct EdgeGlowDemo: View {

    @State private var tapLocation: CGPoint = .zero
    @State private var tapTime:     Date?   = nil
    @State private var hasTapped:   Bool    = false

    private let ringWidth:    Float = 40
    private let maxRadius:    Float = 150
    private let expandTime:   Float = 2.0   // seconds to reach maxRadius
    private let fadeStart:    Float = 0.25
    private let fadeEnd:      Float = 2.0   // fade over the full expansion

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed: Float = tapTime.map { Float(timeline.date.timeIntervalSince($0)) } ?? 0

            // Ring radius grows linearly with time
            let ringRadius = min(elapsed / expandTime, 1.0) * maxRadius

            // Strength fades from 1 → 0 over the expansion
            let strengthProgress = max(0, min((elapsed - fadeStart) / (fadeEnd - fadeStart), 1.0))
            let strength = hasTapped ? (1.0 - strengthProgress) * (1.0 - strengthProgress) : Float(0)

            GeometryReader { geo in
                let size = geo.size

                sceneCanvas(size: size)
                    .layerEffect(
                        ShaderLibrary.edgeGlow(
                            .float2(hasTapped ? Float(tapLocation.x) : Float(size.width / 2),
                                    hasTapped ? Float(tapLocation.y) : Float(size.height / 2)),
                            .float(ringRadius),
                            .float(ringWidth),
                            .float(strength)
                        ),
                        maxSampleOffset: CGSize(width: Double(ringWidth * 2),
                                                height: Double(ringWidth * 2))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        tapLocation = location
                        tapTime     = .now
                        hasTapped   = true
                    }
            }
        }
        .ignoresSafeArea()
    }

    private func sceneCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            // White background
            ctx.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.white)
            )

            let step: CGFloat = 52
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
            var rng = SeededRNG2(seed: 99)

            // Draw black grid lines
            var grid = Path()
            var x: CGFloat = 0
            while x <= canvasSize.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: canvasSize.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= canvasSize.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: canvasSize.width, y: y))
                y += step
            }
            ctx.stroke(grid, with: .color(.black.opacity(0.15)), lineWidth: 1)

            // Draw a random letter centred in each cell
            var col: CGFloat = 0
            while col < canvasSize.width {
                var row: CGFloat = 0
                while row < canvasSize.height {
                    let idx = Int(rng.next() * CGFloat(letters.count)) % letters.count
                    let letter = String(letters[idx])
                    let cx = col + step / 2
                    let cy = row + step / 2
                    ctx.draw(
                        Text(letter)
                            .font(.system(size: 18, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.black),
                        at: CGPoint(x: cx, y: cy),
                        anchor: .center
                    )
                    row += step
                }
                col += step
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SeededRNG2 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
}

#Preview {
    EdgeGlowDemo()
}
