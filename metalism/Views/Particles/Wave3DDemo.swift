//
//  Wave3DDemo.swift
//  metalism
//
//  3-D sine wave surface flowing toward the viewer.
//  Rendered entirely in Metal via ray-marching — monochromatic
//  white/grey palette with diffuse + specular lighting and depth fog.
//

import SwiftUI

struct Wave3DDemo: View {

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size

                Rectangle()
                    .colorEffect(
                        ShaderLibrary.wave3D(
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
    Wave3DDemo()
}
