//
//  RainDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//
//  Rainfall simulation with splash particles at the bottom edge.
//

import SwiftUI

// MARK: - Data Models

struct RainDrop: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var length: CGFloat   // streak length
    var opacity: Double
}

struct SplashParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var life: Double       // 1.0 = fresh, 0.0 = dead
    var radius: CGFloat
}

// MARK: - View Model

@Observable
@MainActor
class RainViewModel {
    var drops: [RainDrop] = []
    var splashes: [SplashParticle] = []

    private var timer: Timer?
    private var canvasSize: CGSize = .zero

    // Slight rightward drift — classic rain angle
    private let driftAngle: CGFloat = 0.0   // radians
    private let gravity: CGFloat = 0.01

    func start(in size: CGSize) {
        canvasSize = size
        // Seed drops spread across the full canvas height so screen isn't empty at first
        drops = (0..<20).map { _ in makeDropSeeded(in: size) }
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

    // A drop that starts at the top
    private func makeDrop(in size: CGSize) -> RainDrop {
        RainDrop(
            x: CGFloat.random(in: -50...size.width + 50),
            y: CGFloat.random(in: -size.height * 0.3 ... 0),
            speed: CGFloat.random(in: 10...22),
            length: CGFloat.random(in: 12...40),
            opacity: Double.random(in: 0.35...0.85)
        )
    }

    // A drop seeded anywhere on screen so the view looks full immediately
    private func makeDropSeeded(in size: CGSize) -> RainDrop {
        RainDrop(
            x: CGFloat.random(in: -50...size.width + 50),
            y: CGFloat.random(in: 0...size.height),
            speed: CGFloat.random(in: 10...22),
            length: CGFloat.random(in: 12...40),
            opacity: Double.random(in: 0.35...0.85)
        )
    }

    private func spawnSplash(at x: CGFloat) {
        let groundY = canvasSize.height
        let count = Int.random(in: 4...8)
        let newSplashes = (0..<count).map { _ -> SplashParticle in
            // Spread outward and slightly upward
            let angle = Double.random(in: -.pi...0)   // upper half arc
            let spd = CGFloat.random(in: 1.5...4.5)
            return SplashParticle(
                position: CGPoint(x: x, y: groundY),
                velocity: CGVector(
                    dx: cos(angle) * spd,
                    dy: sin(angle) * spd
                ),
                life: 1.0,
                radius: CGFloat.random(in: 1...2.5)
            )
        }
        splashes.append(contentsOf: newSplashes)
    }

    private func tick() {
        let w = canvasSize.width
        let h = canvasSize.height
        guard w > 0, h > 0 else { return }

        let dx = tan(driftAngle)

        // --- Update raindrops ---
        for i in drops.indices {
            drops[i].y += drops[i].speed
            drops[i].x += drops[i].speed * dx

            if drops[i].y > h {
                spawnSplash(at: drops[i].x)
                drops[i] = makeDrop(in: canvasSize)
            }
        }

        // --- Update splash particles ---
        for i in splashes.indices {
            splashes[i].velocity.dy += gravity
            splashes[i].position.x += splashes[i].velocity.dx
            splashes[i].position.y += splashes[i].velocity.dy
            splashes[i].life -= 0.055
        }
        splashes.removeAll { $0.life <= 0 }
    }
}

// MARK: - View

struct RainDemo: View {
    @State private var viewModel = RainViewModel()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Draw raindrops as streaks
                for drop in viewModel.drops {
                    let dx = drop.length * tan(0.18)
                    let start = CGPoint(x: drop.x, y: drop.y)
                    let end   = CGPoint(x: drop.x - dx, y: drop.y - drop.length)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)

                    context.stroke(
                        path,
                        with: .color(.gray.opacity(drop.opacity)),
                        lineWidth: 1.2
                    )
                }

                // Draw splash particles
                for splash in viewModel.splashes {
                    let r = splash.radius
                    let rect = CGRect(
                        x: splash.position.x - r,
                        y: splash.position.y - r,
                        width: r * 2,
                        height: r * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.gray.opacity(splash.life * 0.9))
                    )
                }
            }
            .background(Color.black)
            .ignoresSafeArea()
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
    RainDemo()
}
