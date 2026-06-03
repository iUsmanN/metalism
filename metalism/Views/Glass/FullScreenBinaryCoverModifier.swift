//
//  FullScreenBinaryCoverModifier.swift
//  metalism
//
//  Applies the fullScreenBinaryCover shader as a layer effect to any view.
//  Cells animate in on appear and reverse when `isEnabled` is toggled off.
//
//  Usage:
//      MyView()
//          .fullScreenBinaryCover(isEnabled: isOn)
//
//  Optional parameters let you tune cutoff, contrast and animation duration.
//

import SwiftUI

struct FullScreenBinaryCoverModifier: ViewModifier {

    /// Bind to an external toggle to animate the effect in/out.
    var isEnabled: Bool

    var cutoff:       Float  = 0.45
    var contrast:     Float  = 8.0
    var saturation:   Float  = 1.0
    var animDuration: Double = 1.2

    @State private var transitionStart: Date  = .distantPast
    @State private var targetProgress:  Float = 1.0
    @State private var baseProgress:    Float = 0.0
    @State private var viewSize:        CGSize = .zero

    func body(content: Content) -> some View {
        let radius = Float(hypot(viewSize.width, viewSize.height))
        let cx     = Float(viewSize.width  / 2)
        let cy     = Float(viewSize.height / 2)

        TimelineView(.animation) { tl in
            let elapsed = tl.date.timeIntervalSince(transitionStart)
            let t       = Float(min(elapsed / animDuration, 1.0))
            let eased   = t < 0.5 ? 4*t*t*t : 1 - pow(-2*t + 2, 3) / 2
            // Snap to exact target once done — prevents floating-point residue
            // leaving stray partially-visible cells when the effect is at rest.
            let reveal: Float = t >= 1.0 ? targetProgress
                                         : baseProgress + (targetProgress - baseProgress) * eased

            content
                .layerEffect(
                    ShaderLibrary.fullScreenBinaryCover(
                        .float2(cx, cy),
                        .float(radius),
                        .float(radius),
                        .float(cutoff),
                        .float(contrast),
                        .float(0),         // scrollOffset — pass 0 unless the caller overrides
                        .float(reveal),
                        .float(saturation)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewSize = geo.size }
                            .onChange(of: geo.size) { _, s in viewSize = s }
                    }
                )
        }
        .onChange(of: isEnabled) { _, enabled in
            let elapsed = Date.now.timeIntervalSince(transitionStart)
            let t       = Float(min(elapsed / animDuration, 1.0))
            let eased   = t < 0.5 ? 4*t*t*t : 1 - pow(-2*t + 2, 3) / 2
            baseProgress    = baseProgress + (targetProgress - baseProgress) * eased
            targetProgress  = enabled ? 1.0 : 0.0
            transitionStart = .now
        }
        .onAppear {
            baseProgress    = 0.0
            targetProgress  = isEnabled ? 1.0 : 0.0
            transitionStart = .now
        }
    }
}

extension View {
    /// Applies the full-screen binary cover shader with an animated reveal.
    func fullScreenBinaryCover(
        isEnabled: Bool = true,
        cutoff: Float = 0.45,
        contrast: Float = 8.0,
        saturation: Float = 1.0,
        animDuration: Double = 1.2
    ) -> some View {
        modifier(FullScreenBinaryCoverModifier(
            isEnabled: isEnabled,
            cutoff: cutoff,
            contrast: contrast,
            saturation: saturation,
            animDuration: animDuration
        ))
    }
}
