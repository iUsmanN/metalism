//
//  BeesDemo.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//
//  Bee-like motion: each particle has a wander angle that jitters randomly
//  every tick, producing the erratic, darting movement of bees.
//

import SwiftUI

struct Bee: Identifiable {
    let id = UUID()
    var position: CGPoint
    /// Current heading in radians
    var angle: Double
    /// Current speed (magnitude)
    var speed: CGFloat
    /// Timer until next random impulse
    var jitterCountdown: Int
    var radius: CGFloat
    var color: Color
}

@Observable
@MainActor
class BeesViewModel {
    var bees: [Bee] = []
    private var timer: Timer?
    private var canvasSize: CGSize = .zero

    // Amber / honey palette
    private let colors: [Color] = [
        Color(red: 1.0, green: 0.75, blue: 0.0),
        Color(red: 1.0, green: 0.55, blue: 0.0),
        Color(red: 0.9, green: 0.85, blue: 0.1),
        Color(red: 0.6, green: 0.4,  blue: 0.0),
    ]

    func start(in size: CGSize) {
        canvasSize = size
        bees = (0..<40).map { _ in makeBee(in: size) }
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

    private func makeBee(in size: CGSize) -> Bee {
        Bee(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            angle: Double.random(in: 0...(2 * .pi)),
            speed: CGFloat.random(in: 1.5...3.5),
            jitterCountdown: Int.random(in: 4...18),
            radius: CGFloat.random(in: 3...8),
            color: colors.randomElement()!
        )
    }

    private func tick() {
        let w = canvasSize.width
        let h = canvasSize.height
        guard w > 0, h > 0 else { return }

        for i in bees.indices {
            // Count down to the next direction/speed jolt
            bees[i].jitterCountdown -= 1
            if bees[i].jitterCountdown <= 0 {
                // Abrupt heading change — bees pivot sharply
                bees[i].angle += Double.random(in: -.pi...(.pi)) * 0.9
                // Occasionally burst in speed then slow back down
                bees[i].speed = CGFloat.random(in: 1.0...4.5)
                bees[i].jitterCountdown = Int.random(in: 4...20)
            }

            // Small continuous steering noise between jolts
            bees[i].angle += Double.random(in: -0.15...0.15)

            // Advance position
            bees[i].position.x += cos(bees[i].angle) * bees[i].speed
            bees[i].position.y += sin(bees[i].angle) * bees[i].speed

            // Wrap around edges (bees fly off one side and appear on the other)
            if bees[i].position.x < -10 { bees[i].position.x = w + 10 }
            if bees[i].position.x > w + 10 { bees[i].position.x = -10 }
            if bees[i].position.y < -10 { bees[i].position.y = h + 10 }
            if bees[i].position.y > h + 10 { bees[i].position.y = -10 }
        }
    }
}

struct BeesDemo: View {
    @State private var viewModel = BeesViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.02)
                    .ignoresSafeArea()

                ForEach(viewModel.bees) { bee in
                    // Teardrop-ish shape: a circle with a slight trailing shadow
                    Circle()
                        .fill(bee.color)
                        .frame(width: bee.radius * 2, height: bee.radius * 2)
                        .shadow(color: bee.color.opacity(0.7), radius: 4)
                        .position(bee.position)
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
    BeesDemo()
}
