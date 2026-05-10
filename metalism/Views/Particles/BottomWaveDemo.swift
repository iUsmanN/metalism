//
//  BottomWaveDemo.swift
//  metalism
//
//  Black background with a bottom overlay (20% height) that runs an
//  animating sine wave Metal shader scrolling left to right.
//

import SwiftUI

struct BottomWaveDemo: View {

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size
                let panelHeight = size.height * 0.20

                ZStack(alignment: .bottom) {
                    // ── Black background ──────────────────────────────────────
                    Color.black
                        .ignoresSafeArea()

                    // ── Bottom wave panel ─────────────────────────────────────
                    Rectangle()
                        .colorEffect(
                            ShaderLibrary.bottomWave(
                                .float2(Float(size.width), Float(panelHeight)),
                                .float(time)
                            )
                        )
                        .frame(width: size.width, height: panelHeight)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BottomWaveDemo()
}
