//
//  GodRaysDemo.swift
//  metalism
//
//  God rays as parallel diagonal bands of uniform width, all at the same angle,
//  scrolling from right to left at varying per-ray speeds.
//  All rays share one warm white color; opacity fades out toward the bottom edge.
//

import SwiftUI

// MARK: - Ray model

private struct Ray {
    var offsetX: CGFloat    // horizontal position of band centre
    var width: CGFloat      // band width in pixels
    var scrollSpeed: CGFloat // points per second, varies per ray
    var opacity: Double     // base opacity
    var pulseAngle: Double  // drives gentle opacity breathing
    var pulseSpeed: Double
}

// MARK: - ViewModel

@Observable
@MainActor
private class GodRaysViewModel {
    var rays: [Ray] = []
    var screenWidth: CGFloat = 400
    private var timer: Timer?

    var widthRange: ClosedRange<CGFloat> = 24...200

    func start(width: CGFloat, widthRange: ClosedRange<CGFloat>) {
        screenWidth = width
        self.widthRange = widthRange
        buildRays(width: width)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func buildRays(width: CGFloat) {
        let count = 12
        // Spread initial positions across 2× screen width for seamless wrap
        let spacing = (width * 2.0) / CGFloat(count)

        rays = (0..<count).map { i in
            Ray(
                offsetX:     CGFloat(i) * spacing + CGFloat.random(in: -spacing * 0.15...spacing * 0.15),
                width:       CGFloat.random(in: widthRange),
                scrollSpeed: CGFloat.random(in: 1...15),   // vary per ray
                opacity:     Double.random(in: 0.10...0.22),
                pulseAngle:  Double.random(in: 0...(2 * .pi)),
                pulseSpeed:  Double.random(in: 0.004...0.012)
            )
        }
    }

    private func tick() {
        let dt: CGFloat = 1.0 / 60.0
        let totalZone = screenWidth * 2.0
        for i in rays.indices {
            rays[i].offsetX -= rays[i].scrollSpeed * dt
            if rays[i].offsetX < -screenWidth {
                rays[i].offsetX += totalZone
            }
            rays[i].pulseAngle += rays[i].pulseSpeed
        }
    }
}

// MARK: - View

struct GodRaysDemo: View {
    var widthRange: ClosedRange<CGFloat> = 24...70

    @State private var viewModel = GodRaysViewModel()

    // All rays share this single angle (degrees from vertical)
    private let rayAngle: Double = 15 * .pi / 180

    // Single warm-white color for all rays
    private let rayColor = Color(red: 1.0, green: 0.97, blue: 0.88)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            Canvas { context, _ in
                // Dark background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.04, green: 0.04, blue: 0.10),
                            Color(red: 0.08, green: 0.06, blue: 0.18),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                let tilt   = CGFloat(tan(rayAngle)) * size.height
                let top    = -size.height * 0.05
                let bottom =  size.height * 1.05

                for ray in viewModel.rays {
                    let breathe = 0.5 + 0.5 * sin(ray.pulseAngle)
                    let peakOpacity = ray.opacity * (0.55 + 0.45 * breathe)

                    let halfW = ray.width / 2.0

                    let topLeft  = CGPoint(x: ray.offsetX - halfW,        y: top)
                    let topRight = CGPoint(x: ray.offsetX + halfW,        y: top)
                    let botRight = CGPoint(x: ray.offsetX + halfW + tilt, y: bottom)
                    let botLeft  = CGPoint(x: ray.offsetX - halfW + tilt, y: bottom)

                    var band = Path()
                    band.move(to: topLeft)
                    band.addLine(to: topRight)
                    band.addLine(to: botRight)
                    band.addLine(to: botLeft)
                    band.closeSubpath()

                    // Gradient along the ray axis (top → bottom):
                    // fade in from top, hold through middle, fade to zero at bottom edge
                    let topCenter = CGPoint(x: ray.offsetX,        y: top)
                    let botCenter = CGPoint(x: ray.offsetX + tilt, y: bottom)

                    context.drawLayer { layerCtx in
                        layerCtx.addFilter(.blur(radius: 20))
                        layerCtx.fill(band, with: .linearGradient(
                            Gradient(stops: [
                                .init(color: rayColor.opacity(0),           location: 0.00),
                                .init(color: rayColor.opacity(peakOpacity), location: 0.15),
                                .init(color: rayColor.opacity(peakOpacity), location: 0.65),
                                .init(color: rayColor.opacity(0),           location: 1.00),
                            ]),
                            startPoint: topCenter,
                            endPoint:   botCenter
                        ))
                    }
                }
            }
            .onAppear {
                viewModel.start(width: size.width, widthRange: widthRange)
            }
        }
        .ignoresSafeArea()
        .onDisappear { viewModel.stop() }
    }
}

#Preview {
    GodRaysDemo()
}
