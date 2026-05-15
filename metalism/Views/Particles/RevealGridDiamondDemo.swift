//
//  RevealGridDiamondDemo.swift
//  metalism
//

import SwiftUI

struct RevealGridDiamondDemo: View {

    var cols: Int = 9
    var rows: Int = 9

    @State private var startTime: Date? = nil
    private let duration: Float = 1.8

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            let rectW = 300.0
            let rectH = 300.0

            TimelineView(.animation) { tl in
                let progress: Float = {
                    guard let start = startTime else { return 0 }
                    let elapsed = Float(tl.date.timeIntervalSince(start))
                    let cycle = duration + 0.5
                    let t = elapsed.truncatingRemainder(dividingBy: cycle)
                    return min(t / duration, 1.0)
                }()

                ZStack {
                    Color.black.ignoresSafeArea()

                    Rectangle()
                        .fill(Color.red)
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
        .onAppear {
            startTime = .now
        }
    }
}

#Preview {
    NavigationStack {
        RevealGridDiamondDemo()
    }
}
