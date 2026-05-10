//
//  DustShapeDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//
//  Particles are densely packed into the outline of a shape (a star by default).
//  Dragging through them displaces them like dust — they float away and fade out,
//  then fresh replacement particles spawn back at the home position and drift in.
//

import SwiftUI

// MARK: - Particle state

private enum DustState {
    case settled      // at (or near) home, gently wandering
    case displaced    // launched away by the finger, floating freely
    case returning    // springing back to home, fading in
}

private struct DustParticle: Identifiable {
    let id = UUID()
    var home: CGPoint
    var position: CGPoint
    var velocity: CGVector
    var state: DustState
    var life: Double        // kept at 1.0 always — no fading
    var radius: CGFloat
    var wanderAngle: Double
    var wanderSpeed: Double
}

// MARK: - View model

@Observable
@MainActor
private class DustShapeViewModel {
    var particles: [DustParticle] = []
    var dragLocation: CGPoint? = nil

    private var timer: Timer?
    private var canvasSize: CGSize = .zero

    // Tuning
    private let touchRadius: CGFloat   = 35
    private let repelStrength: CGFloat = 8
    private let damping: CGFloat       = 0.94   // high damping → slow float-away
    private let gravity: CGFloat       = 0.012  // gentle downward drift when displaced

    func start(in size: CGSize) {
        canvasSize = size
        buildShape(for: size)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resize(to size: CGSize) {
        guard abs(size.width  - canvasSize.width)  > 1 ||
              abs(size.height - canvasSize.height) > 1 else { return }
        canvasSize = size
        buildShape(for: size)
    }

    // MARK: Shape generation

    /// Returns point positions that lie along the perimeter + filled area of a star.
    private func starPoints(center: CGPoint, outerR: CGFloat, innerR: CGFloat,
                            points: Int, density: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = []
        let spacing: CGFloat = density
        let bounds = CGRect(x: center.x - outerR, y: center.y - outerR,
                            width: outerR * 2, height: outerR * 2)

        // Build the star path
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                             y: center.y + CGFloat(sin(angle)) * r)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()

        // Sample a grid inside the bounding box, keep points inside the path
        var x = bounds.minX
        while x <= bounds.maxX {
            var y = bounds.minY
            while y <= bounds.maxY {
                let pt = CGPoint(x: x, y: y)
                if path.contains(pt) {
                    result.append(pt)
                }
                y += spacing
            }
            x += spacing
        }
        return result
    }

    private func buildShape(for size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outerR = min(size.width, size.height) * 0.38
        let innerR = outerR * 0.42
        let homes  = starPoints(center: center, outerR: outerR, innerR: innerR,
                                points: 5, density: 5)
        particles = homes.map { makeDust(at: $0) }
    }

    private func makeDust(at home: CGPoint) -> DustParticle {
        DustParticle(
            home: home,
            position: home,
            velocity: .zero,
            state: .settled,
            life: 1.0,
            radius: CGFloat.random(in: 0.5...1.4),
            wanderAngle: Double.random(in: 0...(2 * .pi)),
            wanderSpeed: Double.random(in: 0.004...0.015)
        )
    }

    // MARK: Tick

    private func tick() {
        for i in particles.indices {
            switch particles[i].state {

            case .settled:
                // Gentle wander around home
                particles[i].wanderAngle += particles[i].wanderSpeed
                particles[i].wanderAngle += Double.random(in: -0.004...0.004)
                let wa  = particles[i].wanderAngle
                let wr: CGFloat = CGFloat.random(in: 0.3...1.2)
                let targetX = particles[i].home.x + cos(wa) * wr
                let targetY = particles[i].home.y + sin(wa) * wr
                var vx = particles[i].velocity.dx + (targetX - particles[i].position.x) * 0.06
                var vy = particles[i].velocity.dy + (targetY - particles[i].position.y) * 0.06
                vx *= 0.80; vy *= 0.80
                particles[i].velocity  = CGVector(dx: vx, dy: vy)
                particles[i].position.x += vx
                particles[i].position.y += vy
                // Check for touch
                if let drag = dragLocation {
                    let ddx = particles[i].position.x - drag.x
                    let ddy = particles[i].position.y - drag.y
                    let dist = sqrt(ddx * ddx + ddy * ddy)
                    if dist < touchRadius {
                        // Displace: kick outward + random upward scatter
                        let force = (touchRadius - dist) / touchRadius * repelStrength
                        let angle = Double.random(in: -.pi...(.pi))
                        particles[i].velocity = CGVector(
                            dx: (dist > 0 ? ddx / dist : 0) * force + CGFloat(cos(angle)) * 0.6,
                            dy: (dist > 0 ? ddy / dist : 0) * force + CGFloat(sin(angle)) * 0.6 - 1
                        )
                        particles[i].state = .displaced
                    }
                }

            case .displaced:
                // Drift with gravity briefly, then immediately begin returning
                particles[i].velocity.dy += gravity
                particles[i].velocity.dx *= damping
                particles[i].velocity.dy *= damping
                particles[i].position.x  += particles[i].velocity.dx
                particles[i].position.y  += particles[i].velocity.dy
                // Transition to returning after a short drift (velocity has decayed enough)
                let spd = particles[i].velocity.dx * particles[i].velocity.dx
                        + particles[i].velocity.dy * particles[i].velocity.dy
                if spd < 0.8 {
                    particles[i].state = .returning
                }

            case .returning:
                // Slow spring back — low k keeps it gentle, damping prevents overshoot
                let springK: CGFloat    = 0.025
                let springDamp: CGFloat = 0.88
                var vx = particles[i].velocity.dx
                var vy = particles[i].velocity.dy
                vx += (particles[i].home.x - particles[i].position.x) * springK
                vy += (particles[i].home.y - particles[i].position.y) * springK
                vx *= springDamp
                vy *= springDamp
                particles[i].velocity   = CGVector(dx: vx, dy: vy)
                particles[i].position.x += vx
                particles[i].position.y += vy

                let dx = particles[i].position.x - particles[i].home.x
                let dy = particles[i].position.y - particles[i].home.y
                if (dx * dx + dy * dy) < 0.25 && (vx * vx + vy * vy) < 0.01 {
                    particles[i].position = particles[i].home
                    particles[i].velocity = .zero
                    particles[i].state    = .settled
                }
            }
        }
    }
}

// MARK: - View

struct DustShapeDemo: View {
    @State private var viewModel = DustShapeViewModel()

    // Warm dust palette
    private let palette: [Color] = [
        Color(red: 0.95, green: 0.88, blue: 0.65),
        Color(red: 0.90, green: 0.78, blue: 0.50),
        Color(red: 1.0,  green: 0.95, blue: 0.80),
        Color(red: 0.75, green: 0.60, blue: 0.35),
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                for p in viewModel.particles {
                    let r    = p.radius
                    let rect = CGRect(x: p.position.x - r, y: p.position.y - r,
                                     width: r * 2, height: r * 2)
                    // Color index derived from id hash so each particle keeps its colour
                    let color = palette[abs(p.id.hashValue) % palette.count]
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(color.opacity(0.9)))
                }
            }
            .background(Color(red: 0.06, green: 0.04, blue: 0.02))
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in viewModel.dragLocation = value.location }
                    .onEnded   { _     in viewModel.dragLocation = nil            }
            )
            .onAppear    { viewModel.start(in: geo.size)    }
            .onDisappear { viewModel.stop()                  }
            .onChange(of: geo.size) { _, s in viewModel.resize(to: s) }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    DustShapeDemo()
}
