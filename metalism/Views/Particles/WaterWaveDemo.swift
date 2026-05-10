//
//  WaterWaveDemo.swift
//  metalism
//
//  Endless scrolling water cross-section rendered entirely by a Metal
//  colorEffect shader. Sky above, deep water below, foam at the surface,
//  caustic shimmer underwater.
//

import SwiftUI

struct WaterWaveDemo: View {

    // Start time captured once so we pass small elapsed seconds to the shader,
    // avoiding floating-point precision loss from large absolute timestamps.
    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size

                Rectangle()
                    .colorEffect(
                        ShaderLibrary.waterWave(
                            .float2(Float(size.width), Float(size.height)),
                            .float(time)
                        )
                    )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WaterWaveDemo()
}
