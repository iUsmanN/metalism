//
//  Glass.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//

import SwiftUI
struct Glass_05_2026: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.red)
                .frame(width: 200, height: 200)
            VStack {
                Circle()
                    .frame(width: 120, height: 120)
                    .glassEffect(.clear.tint(.green), in: Circle())
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 100, height: 100)
                    .glassEffect(.clear.tint(.yellow), in: Rectangle())
            }
        }
    }
}

#Preview {
    Glass_05_2026()
}
