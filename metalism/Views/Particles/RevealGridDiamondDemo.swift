//
//  RevealGridDiamondDemo.swift
//  metalism
//

import SwiftUI

struct RevealGridDiamondDemo: View {

    var cols: Int = 9
    var rows: Int = 9

    @State private var startTime: Date = .now
    private let duration: Double = 1.8
    private let pause:    Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            let rectW = 300.0
            let rectH = 300.0

            TimelineView(.animation) { tl in
                let cycle    = duration + pause
                let elapsed  = tl.date.timeIntervalSince(startTime).truncatingRemainder(dividingBy: cycle)
                let progress = Float(min(elapsed / duration, 1.0))

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(systemName: "square.and.arrow.up.fill")
                        .resizable()
                        .frame(width: rectW, height: rectH)
                        .colorEffect(
                            ShaderLibrary.revealGridDiamond(
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
        .navigationTitle("Reveal Grid Diamond")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RevealGridDiamondDemo()
    }
}
