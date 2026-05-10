//
//  LightningDemo.swift
//  metalism
//
//  A single lightning bolt that draws itself from top to bottom,
//  then fades out. Tap to trigger a new strike.
//

import SwiftUI

// MARK: - Segment

private struct LightningSegment {
    var start: CGPoint
    var end: CGPoint
}

// MARK: - Strike

private struct Strike {
    var segments: [LightningSegment]   // sorted top → bottom
    var age: Double = 0

    let drawDuration: Double  = 0.12   // seconds to finish drawing
    let holdDuration: Double  = 0.18   // seconds at full brightness
    let fadeDuration: Double  = 0.75   // seconds to fade out
    var lifetime: Double { drawDuration + holdDuration + fadeDuration }
}

// MARK: - Generator

/// Recursive midpoint displacement, no branches.
private func buildSegments(
    from start: CGPoint,
    to end: CGPoint,
    displacement: CGFloat,
    depth: Int,
    into result: inout [LightningSegment]
) {
    guard depth > 0 else {
        result.append(LightningSegment(start: start, end: end))
        return
    }
    let mid = CGPoint(
        x: (start.x + end.x) / 2 + CGFloat.random(in: -displacement...displacement),
        y: (start.y + end.y) / 2
    )
    let next = displacement * 0.6
    buildSegments(from: start, to: mid,  displacement: next, depth: depth - 1, into: &result)
    buildSegments(from: mid,   to: end,  displacement: next, depth: depth - 1, into: &result)
}

// MARK: - ViewModel

@Observable
@MainActor
private class LightningViewModel {
    var strikes: [Strike] = []
    var canvasSize: CGSize = .zero
    private var timer: Timer?

    func start(in size: CGSize) {
        canvasSize = size
        fireStrike()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func fireStrike() {
        guard canvasSize.width > 0 else { return }
        let x     = CGFloat.random(in: canvasSize.width * 0.25 ... canvasSize.width * 0.75)
        let start = CGPoint(x: x, y: 0)
        let end   = CGPoint(x: x + CGFloat.random(in: -80...80), y: canvasSize.height)

        var segs: [LightningSegment] = []
        buildSegments(from: start, to: end, displacement: 60, depth: 7, into: &segs)
        // Already in top-to-bottom order from recursion, but sort to be safe
        segs.sort { $0.start.y < $1.start.y }

        strikes.append(Strike(segments: segs))
    }

    private func tick() {
        let dt = 1.0 / 60.0
        for i in strikes.indices { strikes[i].age += dt }
        strikes.removeAll { $0.age >= $0.lifetime }
    }
}

// MARK: - View

struct LightningDemo: View {
    @State private var viewModel = LightningViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Canvas { context, _ in
                    for strike in viewModel.strikes {
                        let age = strike.age

                        // How many segments to reveal (draw phase)
                        let drawProgress = min(age / strike.drawDuration, 1.0)
                        let visibleCount = Int(Double(strike.segments.count) * drawProgress)

                        // Opacity: hold then fade
                        let opacity: Double
                        if age < strike.drawDuration + strike.holdDuration {
                            opacity = 1.0
                        } else {
                            let fadeAge = age - strike.drawDuration - strike.holdDuration
                            opacity = max(0, 1.0 - fadeAge / strike.fadeDuration)
                        }

                        for i in 0..<visibleCount {
                            let seg = strike.segments[i]
                            var path = Path()
                            path.move(to: seg.start)
                            path.addLine(to: seg.end)

                            // Outer glow
                            context.stroke(path,
                                with: .color(Color(red: 0.55, green: 0.65, blue: 1.0).opacity(opacity * 0.3)),
                                lineWidth: 12)
                            // Mid glow
                            context.stroke(path,
                                with: .color(Color(red: 0.75, green: 0.85, blue: 1.0).opacity(opacity * 0.65)),
                                lineWidth: 4)
                            // Core
                            context.stroke(path,
                                with: .color(Color.white.opacity(opacity)),
                                lineWidth: 1.2)
                        }
                    }
                }
                .ignoresSafeArea()

                if viewModel.strikes.isEmpty {
                    Text("Tap to strike")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .onTapGesture   { viewModel.fireStrike() }
            .onAppear       { viewModel.start(in: geo.size) }
            .onDisappear    { viewModel.stop() }
            .onChange(of: geo.size) { _, s in viewModel.canvasSize = s }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LightningDemo()
}
