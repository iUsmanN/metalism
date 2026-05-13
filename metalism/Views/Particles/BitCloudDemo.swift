//
//  BitCloudDemo.swift
//  metalism
//
//  Full-screen grid of 0s and 1s. Cloud-shaped regions (metaball blobs drifting
//  downward) show "0"; background shows "1". White letters, black background.
//

import SwiftUI

struct BitCloudDemo: View {

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            let time = Float(tl.date.timeIntervalSince(startDate))

            GeometryReader { geo in
                let size = geo.size
                Color.black
                    .colorEffect(
                        ShaderLibrary.redCloud(
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
    BitCloudDemo()
}
