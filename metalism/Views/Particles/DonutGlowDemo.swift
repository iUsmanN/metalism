//
//  DonutGlowDemo.swift
//  metalism
//
//  Tap anywhere. A clear circle sits at the tap point; blur + chromatic
//  aberration fills the doughnut ring beyond it. The ring expands outward
//  and fades over time.
//

import SwiftUI

struct DonutGlowDemo: View {

    @State private var tapLocation: CGPoint = .zero
    @State private var tapTime:     Date?   = nil
    @State private var hasTapped:   Bool    = false

    // Inner clear radius (grows slightly with time)
    private let innerStart:   Float = 20
    private let innerEnd:     Float = 40

    // Outer boundary of the effect ring
    private let outerStart:   Float = 40
    private let outerEnd:     Float = 230

    private let expandTime:   Float = 3.0   // seconds to reach max size
    private let fadeEnd:      Float = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed: Float = tapTime.map { Float(timeline.date.timeIntervalSince($0)) } ?? 0

            let progress     = min(elapsed / expandTime, 1.0)
            let innerRadius  = innerStart + progress * (innerEnd - innerStart)
            let outerRadius  = outerStart + progress * (outerEnd - outerStart)

            let fadeProgress = max(0, min(elapsed / fadeEnd, 1.0))
            let strength     = hasTapped ? (1.0 - fadeProgress) * (1.0 - fadeProgress) : Float(0)

            // maxSampleOffset must cover aberration + blur reach
            let sampleBound  = Double(outerEnd * 0.15 + 10)

            GeometryReader { geo in
                let size = geo.size

                sceneCanvas(size: size)
                    .layerEffect(
                        ShaderLibrary.donutGlow(
                            .float2(hasTapped ? Float(tapLocation.x) : Float(size.width / 2),
                                    hasTapped ? Float(tapLocation.y) : Float(size.height / 2)),
                            .float(innerRadius),
                            .float(outerRadius),
                            .float(strength)
                        ),
                        maxSampleOffset: CGSize(width: sampleBound, height: sampleBound)
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
            var rng = SeededRNG3(seed: 42)

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
            ctx.stroke(grid, with: .color(.black.opacity(0.15)), lineWidth: 1)

            // Random letter in each cell
            var col: CGFloat = 0
            while col < canvasSize.width {
                var row: CGFloat = 0
                while row < canvasSize.height {
                    let idx    = Int(rng.next() * CGFloat(letters.count)) % letters.count
                    let letter = String(letters[idx])
                    ctx.draw(
                        Text(letter)
                            .font(.system(size: 18, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.black),
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

private struct SeededRNG3 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
}

#Preview {
    DonutGlowDemo()
}
