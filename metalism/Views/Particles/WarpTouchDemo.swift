//
//  WarpTouchDemo.swift
//  metalism
//
//  Single shader pass over the whole view. Trail point data is packed into
//  float arrays and sent as buffer uniforms — one GPU pass per frame.
//

import SwiftUI

private struct TrailPoint {
    let position: CGPoint
    let direction: CGSize
    let timestamp: Date
}

struct WarpTouchDemo: View {

    @State private var trail: [TrailPoint] = []

    private let trailDuration: TimeInterval = 0.5  // short window — keeps directions coherent
    private let maxTrailPoints: Int = 20            // cap so old conflicting points don't pile up
    private let radius: Float  = 140
    private let maxStrength: Float = 80

    var body: some View {
        TimelineView(.animation) { (timeline: TimelineViewDefaultContext) in
            let now = timeline.date
            let packed = packTrail(now: now)

            GeometryReader { geo in
                let size = geo.size

                backgroundContent(size: size)
                    .layerEffect(
                        ShaderLibrary.warpTouch(
                            .float2(size.width, size.height),
                            .floatArray(packed.points),
                            .floatArray(packed.dirs),
                            .floatArray(packed.strengths),
                            .float(radius)
                        ),
                        maxSampleOffset: CGSize(width: CGFloat(radius + maxStrength),
                                                height: CGFloat(radius + maxStrength))
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let v = value.velocity
                                let len = sqrt(v.width * v.width + v.height * v.height)
                                let dir = len > 1
                                    ? CGSize(width: v.width / len, height: v.height / len)
                                    : (trail.last?.direction ?? CGSize(width: 1, height: 0))

                                trail.append(TrailPoint(
                                    position: value.location,
                                    direction: dir,
                                    timestamp: .now
                                ))
                                // Remove expired and keep only most recent maxTrailPoints
                                trail.removeAll { Date.now.timeIntervalSince($0.timestamp) >= trailDuration }
                                if trail.count > maxTrailPoints {
                                    trail.removeFirst(trail.count - maxTrailPoints)
                                }
                            }
                            .onEnded { _ in }
                    )
                    .onChange(of: now) { _, _ in
                        trail.removeAll { now.timeIntervalSince($0.timestamp) >= trailDuration }
                    }
            }
        }
        .ignoresSafeArea()
    }

    private struct PackedTrail {
        var points: [Float]
        var dirs: [Float]
        var strengths: [Float]
    }

    private func packTrail(now: Date) -> PackedTrail {
        let live = trail.filter { now.timeIntervalSince($0.timestamp) < trailDuration }
        let count = min(live.count, maxTrailPoints)
        var points    = [Float](repeating: 0, count: max(count * 2, 2))
        var dirs      = [Float](repeating: 0, count: max(count * 2, 2))
        var strengths = [Float](repeating: 0, count: max(count, 1))
        for i in 0..<count {
            let p = live[i]
            let age = Float(now.timeIntervalSince(p.timestamp))
            let progress = age / Float(trailDuration)
            // Smooth cubic fade — gentle taper rather than sharp drop
            let fade = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
            points[i * 2]     = Float(p.position.x)
            points[i * 2 + 1] = Float(p.position.y)
            dirs[i * 2]       = Float(p.direction.width)
            dirs[i * 2 + 1]   = Float(p.direction.height)
            // Most recent point always full strength
            let isNewest = (i == count - 1)
            strengths[i] = isNewest ? maxStrength : maxStrength * fade
        }
        return PackedTrail(points: points, dirs: dirs, strengths: strengths)
    }

    // MARK: - Background

    private func backgroundContent(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.10, green: 0.05, blue: 0.25),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                )
            )

            let step: CGFloat = 40
            var gridPath = Path()
            var x: CGFloat = 0
            while x <= canvasSize.width {
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= canvasSize.height {
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
                y += step
            }
            context.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)

            let dotR: CGFloat = 1.5
            var dotsPath = Path()
            var dx: CGFloat = 0
            while dx <= canvasSize.width {
                var dy: CGFloat = 0
                while dy <= canvasSize.height {
                    dotsPath.addEllipse(in: CGRect(x: dx - dotR, y: dy - dotR,
                                                   width: dotR * 2, height: dotR * 2))
                    dy += step
                }
                dx += step
            }
            context.fill(dotsPath, with: .color(.white.opacity(0.25)))
        }
        .frame(width: size.width, height: size.height)
    }
}

#Preview {
    WarpTouchDemo()
}
