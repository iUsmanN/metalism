//
//  ConfettiDemo.swift
//  metalism
//
//  Confetti falling from the top of the screen.
//  Set `duration` to control how many seconds new pieces spawn.
//  After that window closes, existing pieces finish falling and fade out.
//

import SwiftUI

// MARK: - Color mode

enum ConfettiColorMode {
    case random
    case single(Color)
    case palette([Color])
}

// MARK: - Model

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat   // horizontal drift
    var velocityY: CGFloat   // downward speed
    var rotation: Double     // current rotation (degrees)
    var rotationSpeed: Double
    var width: CGFloat
    var height: CGFloat
    var color: Color
    var opacity: Double
    var wobbleAngle: Double  // drives horizontal oscillation
    var wobbleSpeed: Double
}

// MARK: - ViewModel

@Observable
@MainActor
class ConfettiViewModel {
    var pieces: [ConfettiPiece] = []

    /// How many seconds to spawn new confetti. Set before calling start().
    var duration: Double = 3.0

    /// Controls which colours are used. Default is .random.
    var colorMode: ConfettiColorMode = .random

    private var timer: Timer?
    private var spawnTimer: Timer?
    private var canvasSize: CGSize = .zero
    private var spawnActive = true

    private let defaultColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink,
        Color(red: 1, green: 0.4, blue: 0.7),
        Color(red: 0.3, green: 1, blue: 0.5),
    ]

    func start(in size: CGSize) {
        canvasSize = size
        spawnActive = true

        // Ongoing spawn ticker
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self, self.spawnActive else { return }
            for _ in 0..<3 {
                self.pieces.append(self.makePiece(in: self.canvasSize))
            }
        }

        // Stop spawning after `duration` seconds
        Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.spawnActive = false
            self?.spawnTimer?.invalidate()
            self?.spawnTimer = nil
        }

        // Physics tick at 60 fps
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    func resize(to size: CGSize) {
        canvasSize = size
    }

    private func makePiece(in size: CGSize) -> ConfettiPiece {
        ConfettiPiece(
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: -120 ... -10),
            velocityX: CGFloat.random(in: -0.6...0.6),
            velocityY: CGFloat.random(in: 2.5...6.0),
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -4...4),
            width: CGFloat.random(in: 7...16),
            height: CGFloat.random(in: 4...9),
            color: resolveColor(),
            opacity: Double.random(in: 0.8...1.0),
            wobbleAngle: Double.random(in: 0...(2 * .pi)),
            wobbleSpeed: Double.random(in: 0.04...0.12)
        )
    }

    private func resolveColor() -> Color {
        switch colorMode {
        case .random:                  return defaultColors.randomElement()!
        case .single(let c):           return c
        case .palette(let palette):    return palette.isEmpty ? defaultColors.randomElement()! : palette.randomElement()!
        }
    }

    private func tick() {
        let h = canvasSize.height
        guard h > 0 else { return }

        for i in pieces.indices {
            // Wobble — horizontal sine oscillation like paper tumbling in air
            pieces[i].wobbleAngle += pieces[i].wobbleSpeed
            let wobble = CGFloat(sin(pieces[i].wobbleAngle)) * 1.2

            pieces[i].x        += pieces[i].velocityX + wobble
            pieces[i].y        += pieces[i].velocityY
            pieces[i].rotation += pieces[i].rotationSpeed

            // Fade out near the bottom
            let fadeStart = h * 0.80
            if pieces[i].y > fadeStart {
                pieces[i].opacity = max(0, 1.0 - Double((pieces[i].y - fadeStart) / (h * 0.2)))
            }
        }

        // Remove pieces that have fallen off screen and fully faded
        pieces.removeAll { $0.y > h + 20 || $0.opacity <= 0 }
    }
}

// MARK: - View

struct ConfettiDemo: View {
    /// Seconds to spawn new confetti before stopping.
    var duration: Double = 4.0

    /// Colour mode: .random, .single(color), or .palette([colors])
    var colorMode: ConfettiColorMode = .random

    @State private var viewModel = ConfettiViewModel()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                for piece in viewModel.pieces {
                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2,
                                     width: piece.width, height: piece.height)
                    // Draw each piece in its own isolated context so transforms don't accumulate
                    context.drawLayer { ctx in
                        ctx.translateBy(x: piece.x, y: piece.y)
                        ctx.rotate(by: .degrees(piece.rotation))
                        ctx.fill(Path(rect), with: .color(piece.color.opacity(piece.opacity)))
                    }
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.10))
            .ignoresSafeArea()
            .onAppear {
                viewModel.duration  = duration
                viewModel.colorMode = colorMode
                viewModel.start(in: geo.size)
            }
            .onDisappear { viewModel.stop() }
            .onChange(of: geo.size) { _, s in viewModel.resize(to: s) }
        }
        .ignoresSafeArea()
    }
}

#Preview("Random colors") {
    ConfettiDemo(duration: 3.0, colorMode: .random)
}
#Preview("Single color") {
    ConfettiDemo(duration: 3.0, colorMode: .single(.cyan))
}

#Preview("Custom palette") {
    ConfettiDemo(duration: 0.75, colorMode: .palette([.red, .yellow, .orange]))
}

