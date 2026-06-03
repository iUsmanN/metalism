//
//  RevealGridSequentialDemo.swift
//  metalism
//

import SwiftUI

struct RevealGridSequentialDemo: View {

    var cols: Int = 15
    var rows: Int = 15

    @State private var startTime: Date = .now
    private let duration: Double = 1.8
    private let pause:    Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            let rectW = screenSize.width  * 0.6
            let rectH = screenSize.height * 0.6

            TimelineView(.animation) { tl in
                let cycle    = duration + pause
                let elapsed  = tl.date.timeIntervalSince(startTime).truncatingRemainder(dividingBy: cycle)
                let progress = Float(min(elapsed / duration, 1.0))

                ZStack {
                    Color.black.ignoresSafeArea()

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: rectW, height: rectH)
                        .colorEffect(
                            ShaderLibrary.revealGridSequential(
                                .float2(Float(rectW), Float(rectH)),
                                .float(progress),
                                .float(Float(cols)),
                                .float(Float(rows))
                            )
                        )
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Reveal Grid Sequential")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RevealGridSequentialDemo()
    }
}
