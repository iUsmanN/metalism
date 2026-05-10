//
//  RepelDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//
//  A grid of static particles that scatter away from the finger/cursor
//  and spring back to their home positions when released.
//

import SwiftUI

// MARK: - Data Model

struct RepelParticle: Identifiable {
    let id = UUID()
    var home: CGPoint       // resting position
    var position: CGPoint   // current position
    var velocity: CGVector
    var color: Color
    var radius: CGFloat
    // Wander: each particle orbits its home along a slowly shifting angle
    var wanderAngle: Double         // current angle around home
    var wanderSpeed: Double         // how fast the angle advances per tick
    var wanderRadius: CGFloat       // how far it strays from home
    var pulseAngle: Double          // drives the opacity oscillation
    var pulseSpeed: Double          // how fast opacity cycles
    var opacity: Double             // current rendered opacity
}

// MARK: - View Model

@Observable
@MainActor
class RepelViewModel {
    var particles: [RepelParticle] = []
    var dragLocation: CGPoint? = nil

    private var timer: Timer?
    private var canvasSize: CGSize = .zero

    // Tuning
    private let repelRadius: CGFloat = 80
    private let repelStrength: CGFloat = 18
    private let springStrength: CGFloat = 0.08
    private let damping: CGFloat = 0.82

    func start(in size: CGSize) {
        canvasSize = size
        buildGrid(for: size)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resize(to size: CGSize) {
        // Rebuild the grid only if the size changed meaningfully
        guard abs(size.width - canvasSize.width) > 1 || abs(size.height - canvasSize.height) > 1 else { return }
        canvasSize = size
        buildGrid(for: size)
    }

    private func buildGrid(for size: CGSize) {
        let cols = Int(size.width / 22)
        let rows = Int(size.height / 22)
        let xSpacing = size.width / CGFloat(cols)
        let ySpacing = size.height / CGFloat(rows)

        let palette: [Color] = [
            Color(red: 1.0,  green: 0.84, blue: 0.0),
            Color(red: 1.0,  green: 0.76, blue: 0.1),
            Color(red: 0.95, green: 0.90, blue: 0.3),
            Color(red: 0.85, green: 0.65, blue: 0.0),
        ]

        particles = (0..<rows).flatMap { row in
            (0..<cols).map { col in
                let home = CGPoint(
                    x: xSpacing * (CGFloat(col) + 0.5),
                    y: ySpacing * (CGFloat(row) + 0.5)
                )
                return RepelParticle(
                    home: home,
                    position: home,
                    velocity: .zero,
                    color: palette.randomElement()!,
                    radius: CGFloat.random(in: 1.5...3.5),
                    wanderAngle: Double.random(in: 0...(2 * .pi)),
                    wanderSpeed: Double.random(in: 0.003...0.012),
                    wanderRadius: CGFloat.random(in: 0.5...2.0),
                    pulseAngle: Double.random(in: 0...(2 * .pi)),
                    pulseSpeed: Double.random(in: 0.01...0.035),
                    opacity: 1.0
                )
            }
        }
    }

    private func tick() {
        for i in particles.indices {
            var vx = particles[i].velocity.dx
            var vy = particles[i].velocity.dy
            var px = particles[i].position.x
            var py = particles[i].position.y

            // Advance the wander angle with a tiny random jitter so motion is irregular
            particles[i].wanderAngle += particles[i].wanderSpeed
            particles[i].wanderAngle += Double.random(in: -0.003...0.003)

            // Pulse opacity between 0.6 and 1.0
            particles[i].pulseAngle += particles[i].pulseSpeed
            particles[i].opacity = 0.5 + 0.5 * sin(particles[i].pulseAngle)

            // Compute the wandering target offset from home
            let wr = particles[i].wanderRadius
            let wa = particles[i].wanderAngle
            let targetX = particles[i].home.x + cos(wa) * wr
            let targetY = particles[i].home.y + sin(wa) * wr

            // Spring back toward the wandering target instead of the bare home position
            vx += (targetX - px) * springStrength
            vy += (targetY - py) * springStrength

            // Repel from drag location
            if let drag = dragLocation {
                let ddx = px - drag.x
                let ddy = py - drag.y
                let dist = sqrt(ddx * ddx + ddy * ddy)
                if dist < repelRadius && dist > 0 {
                    let force = (repelRadius - dist) / repelRadius * repelStrength
                    vx += (ddx / dist) * force
                    vy += (ddy / dist) * force
                }
            }

            // Dampen
            vx *= damping
            vy *= damping

            particles[i].velocity = CGVector(dx: vx, dy: vy)
            particles[i].position = CGPoint(x: px + vx, y: py + vy)
        }
    }
}

// MARK: - View

struct RepelDemo: View {
    @State private var viewModel = RepelViewModel()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                for p in viewModel.particles {
                    let r = p.radius
                    let rect = CGRect(x: p.position.x - r, y: p.position.y - r,
                                     width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(p.opacity)))
                }
            }
            .background(Color.black)
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        viewModel.dragLocation = value.location
                    }
                    .onEnded { _ in
                        viewModel.dragLocation = nil
                    }
            )
            .onAppear {
                viewModel.start(in: geo.size)
            }
            .onDisappear {
                viewModel.stop()
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.resize(to: newSize)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    RepelDemo()
}
