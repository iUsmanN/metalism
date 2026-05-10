//
//  WavePerspectiveDemo.swift
//  metalism
//
//  A sine wave band flows toward the viewer in perspective.
//  Chromatic aberration peaks as the wave nears the camera;
//  opacity drops to zero at the closest point.
//

import SwiftUI

struct WavePerspectiveDemo: View {

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size

                // Background: white grid + random letters (same as EdgeGlowDemo)
                sceneCanvas(size: size)
                    .layerEffect(
                        ShaderLibrary.wavePerspective(
                            .float2(Float(size.width), Float(size.height)),
                            .float(time)
                        ),
                        maxSampleOffset: CGSize(width: 32, height: 0)
                    )
            }
        }
        .ignoresSafeArea()
    }

    private func sceneCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            // Black background
            ctx.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.black)
            )

            let step: CGFloat = 52
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
            var rng = SeededRNGWave(seed: 13)

            // Grid lines
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
            ctx.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)

            // Random letter per cell
            var col: CGFloat = 0
            while col < canvasSize.width {
                var row: CGFloat = 0
                while row < canvasSize.height {
                    let idx    = Int(rng.next() * CGFloat(letters.count)) % letters.count
                    let letter = String(letters[idx])
                    ctx.draw(
                        Text(letter)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white),
                        at: CGPoint(x: col + step / 2, y: row + step / 2),
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

private struct SeededRNGWave {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
}

#Preview {
    WavePerspectiveDemo()
}
