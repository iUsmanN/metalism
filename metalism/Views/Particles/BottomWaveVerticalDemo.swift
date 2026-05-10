//
//  BottomWaveVerticalDemo.swift
//  metalism
//
//  Black background with a bottom overlay (20% height) running two
//  vertical-gradient sine waves in opposite directions and different
//  colours, composited additively via .screen blend mode.
//

import SwiftUI

struct BottomWaveVerticalDemo: View {

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size
                let panelHeight = size.height * 0.20

                ZStack(alignment: .bottom) {
                    Color.black
                        .ignoresSafeArea()

                    // Wave 1 — cyan, left → right
                    Color.black
                        .colorEffect(
                            ShaderLibrary.bottomWaveVertical(
                                .float2(Float(size.width), Float(panelHeight)),
                                .float(time),
                                .float(1.0),
                                .float3(0.0, 0.5, 1.0)
                            )
                        )
                        .blendMode(.screen)
                        .frame(width: size.width, height: panelHeight)

                    // Wave 2 — magenta, right → left, screened on top
                    Color.black
                        .colorEffect(
                            ShaderLibrary.bottomWaveVertical(
                                .float2(Float(size.width), Float(panelHeight)),
                                .float(time),
                                .float(-1.0),
                                .float3(1.0, 0.2, 0.0)
                            )
                        )
                        .blendMode(.screen)
                        .frame(width: size.width, height: panelHeight)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BottomWaveVerticalDemo()
}
