//
//  ParticlesDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//

import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var color: Color
    var opacity: Double
}

@Observable
@MainActor
class ParticlesViewModel {
    var particles: [Particle] = []
    private var displayLink: Timer?
    private var canvasSize: CGSize = .zero

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    func start(in size: CGSize) {
        canvasSize = size
        particles = (0..<60).map { _ in makeParticle(in: size) }
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func resize(to size: CGSize) {
        canvasSize = size
    }

    private func makeParticle(in size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -1.2...1.2),
                dy: CGFloat.random(in: -1.2...1.2)
            ),
            radius: CGFloat.random(in: 4...14),
            color: colors.randomElement()!,
            opacity: Double.random(in: 0.5...1.0)
        )
    }

    private func tick() {
        let w = canvasSize.width
        let h = canvasSize.height
        guard w > 0, h > 0 else { return }

        for i in particles.indices {
            particles[i].position.x += particles[i].velocity.dx
            particles[i].position.y += particles[i].velocity.dy

            // Bounce off edges
            if particles[i].position.x < 0 || particles[i].position.x > w {
                particles[i].velocity.dx *= -1
                particles[i].position.x = max(0, min(w, particles[i].position.x))
            }
            if particles[i].position.y < 0 || particles[i].position.y > h {
                particles[i].velocity.dy *= -1
                particles[i].position.y = max(0, min(h, particles[i].position.y))
            }
        }
    }
}

struct ParticlesDemo: View {
    @State private var viewModel = ParticlesViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                ForEach(viewModel.particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.radius * 2, height: particle.radius * 2)
                        .opacity(particle.opacity)
                        .blur(radius: 1.5)
                        .position(particle.position)
                }
            }
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
    ParticlesDemo()
}
