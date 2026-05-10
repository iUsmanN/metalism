//
//  LiquidBlockModifier.swift
//  metalism
//
//  A reusable modifier that applies the liquid-block shader to any view.
//  The shader operates in the view's own coordinate space, so centre is
//  always (width/2, height/2) — it works on any sized view automatically.
//
//  Usage:
//      AnyView()
//          .liquidBlock(cornerRadius: 12, ringWidth: 28)
//

import SwiftUI

struct LiquidBlockModifier: ViewModifier {

    var cornerRadius: CGFloat
    var ringWidth: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let size   = geo.size
            let cx     = Float(size.width  / 2)
            let cy     = Float(size.height / 2)
            content
                .frame(width: size.width, height: size.height)
                .layerEffect(
                    ShaderLibrary.liquidBlock(
                        .float2(cx, cy),
                        .float2(cx, cy),
                        .float(Float(cornerRadius)),
                        .float(Float(ringWidth))
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )
        }
    }
}

extension View {
    /// Applies the liquid-block frosted-glass shader to this view.
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the effect region (default 8).
    ///   - ringWidth: Width in points of the edge refraction/warp ring (default 28).
    func liquidBlock(
        cornerRadius: CGFloat = 8,
        ringWidth: CGFloat = 28
    ) -> some View {
        modifier(LiquidBlockModifier(cornerRadius: cornerRadius, ringWidth: ringWidth))
    }
}
