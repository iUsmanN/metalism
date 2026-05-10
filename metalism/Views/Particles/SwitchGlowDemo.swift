//
//  SwitchGlowDemo.swift
//  metalism
//
//  Toggle the switch to fire a wavefront that starts as a circle at the
//  card centre and morphs into a square as it expands to the card bounds.
//  Blur + chromatic aberration ride the wavefront, fading as it travels.
//

import SwiftUI

struct SwitchGlowDemo: View {

    @State private var isOn:      Bool  = false
    @State private var triggerTime: Date? = nil
    @State private var cardSize:  CGSize = .zero

    // Animation timing
    private let expandDuration: Float = 0.9   // seconds to reach card corner
    private let ringWidth:      Float = 55    // half-thickness of the effect band

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Card with shader
                TimelineView(.animation) { timeline in
                    let elapsed = triggerTime.map { Float(timeline.date.timeIntervalSince($0)) } ?? -1

                    // Half-diagonal of the card — ring needs to reach the corners
                    let halfDiag = Float(sqrt(cardSize.width * cardSize.width +
                                              cardSize.height * cardSize.height)) / 2

                    // Ring travels from 0 → halfDiag over expandDuration
                    let progress    = elapsed < 0 ? Float(-1) : min(elapsed / expandDuration, 1.0)
                    let ringRadius  = max(progress, 0) * halfDiag

                    // Squareness: 0 (circle) → 1 (square) as ring expands
                    let squareness  = max(progress, 0)

                    // Strength: full at start, fades out over the expansion
                    let strength: Float = elapsed < 0 ? 0 :
                        (1.0 - min(elapsed / expandDuration, 1.0))

                    GeometryReader { geo in
                        cardCanvas(size: geo.size)
                            .layerEffect(
                                ShaderLibrary.switchGlow(
                                    .float2(Float(geo.size.width  / 2),
                                            Float(geo.size.height / 2)),
                                    .float(ringRadius),
                                    .float(ringWidth),
                                    .float(squareness),
                                    .float(strength)
                                ),
                                maxSampleOffset: CGSize(
                                    width:  Double(ringWidth + 12),
                                    height: Double(ringWidth + 12)
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                            .onAppear { cardSize = geo.size }
                    }
                    .frame(height: 320)
                    .padding(.horizontal, 28)
                }

                // Toggle control
                HStack(spacing: 16) {
                    Text(isOn ? "On" : "Off")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isOn ? Color.indigo : Color.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isOn)

                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .tint(.indigo)
                        .onChange(of: isOn) { _, _ in
                            triggerTime = Date.now
                        }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
                .padding(.horizontal, 60)

                Spacer()
            }
        }
    }

    // MARK: - Card canvas

    private func cardCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            ctx.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.22))
            )

            let step: CGFloat = 36
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
            ctx.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 0.5)

            let palette: [Color] = [
                Color(red: 0.45, green: 0.55, blue: 1.0),
                Color(red: 0.85, green: 0.40, blue: 0.70),
                Color(red: 0.35, green: 0.85, blue: 0.75),
                Color(red: 1.00, green: 0.70, blue: 0.30),
                Color(red: 0.65, green: 0.40, blue: 1.00),
            ]
            var rng = SeededRNGSwitch(seed: 77)
            for _ in 0..<18 {
                let cx = rng.next() * canvasSize.width
                let cy = rng.next() * canvasSize.height
                let r  = 8 + rng.next() * 22
                let c  = palette[Int(rng.next() * CGFloat(palette.count)) % palette.count]
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(c.opacity(0.5))
                )
            }

            ctx.draw(
                Text("Toggle the switch")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.35)),
                at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                anchor: .center
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SeededRNGSwitch {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
}

#Preview {
    SwitchGlowDemo()
}
