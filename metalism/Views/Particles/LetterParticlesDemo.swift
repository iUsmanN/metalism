//
//  LetterParticlesDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//
//  ParticlesDemo variant where each particle is a floating letter
//  instead of a circle.
//

import SwiftUI

struct LetterParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var fontSize: CGFloat
    var color: Color
    var opacity: Double
    var letter: String
    var rotation: Double       // degrees
    var rotationSpeed: Double  // degrees per tick
}

@Observable
@MainActor
class LetterParticlesViewModel {
    var particles: [LetterParticle] = []
    private var timer: Timer?
    private var canvasSize: CGSize = .zero

    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .pink]
    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    func start(in size: CGSize) {
        canvasSize = size
        particles = (0..<50).map { _ in makeParticle(in: size) }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resize(to size: CGSize) {
        canvasSize = size
    }

    private func makeParticle(in size: CGSize) -> LetterParticle {
        LetterParticle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -0.2...0.2),
                dy: CGFloat.random(in: -0.2...0.2)
            ),
            fontSize: CGFloat.random(in: 12...36),
            color: .orange,
            opacity: Double.random(in: 0.5...1.0),
            letter: String(letters.randomElement()!),
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -1.2...1.2)
        )
    }

    private func tick() {
        let w = canvasSize.width
        let h = canvasSize.height
        guard w > 0, h > 0 else { return }

        for i in particles.indices {
            particles[i].position.x += particles[i].velocity.dx
            particles[i].position.y += particles[i].velocity.dy
            particles[i].rotation   += particles[i].rotationSpeed

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

struct LetterParticlesDemo: View {
    @State private var viewModel = LetterParticlesViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                ForEach(viewModel.particles) { p in
                    Text(p.letter)
                        .font(.system(size: p.fontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(p.color)
                        .opacity(p.opacity)
                        .rotationEffect(.degrees(p.rotation))
                        .position(p.position)
                }
            }
            .onAppear    { viewModel.start(in: geo.size)         }
            .onDisappear { viewModel.stop()                       }
            .onChange(of: geo.size) { _, s in viewModel.resize(to: s) }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LetterParticlesDemo()
}
