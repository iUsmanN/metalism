//
//  RedBottomListDemo.swift
//  metalism
//
//  List rows drawn entirely in a SwiftUI Canvas so layerEffect works.
//  The Metal shader tints the bottom 10% red and stretches those pixels
//  vertically proportional to the red intensity.
//

import SwiftUI

struct RedBottomListDemo: View {

    private let items: [String] = (1...40).map { "Item \($0)" }
    @State private var scrollOffset: CGFloat = 0

    private let rowHeight: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let totalHeight = CGFloat(items.count) * rowHeight

            ScrollView {
                GeometryReader { inner in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self,
                                    value: inner.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                Canvas { ctx, canvasSize in
                    let offsetY = -scrollOffset

                    ctx.fill(Path(CGRect(origin: .zero, size: canvasSize)),
                             with: .color(Color(uiColor: .systemBackground)))

                    for (i, item) in items.enumerated() {
                        let rowY = CGFloat(i) * rowHeight - offsetY
                        guard rowY < canvasSize.height && rowY + rowHeight > 0 else { continue }

                        var div = Path()
                        div.move(to: CGPoint(x: 68, y: rowY + rowHeight - 0.5))
                        div.addLine(to: CGPoint(x: canvasSize.width, y: rowY + rowHeight - 0.5))
                        ctx.stroke(div, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)

                        let badgeRect = CGRect(x: 16, y: rowY + (rowHeight - 36) / 2,
                                              width: 36, height: 36)
                        ctx.fill(Path(roundedRect: badgeRect, cornerRadius: 6),
                                 with: .color(.blue.opacity(0.12)))

                        ctx.draw(
                            Text(item).font(.body).foregroundStyle(Color.primary),
                            at: CGPoint(x: 68, y: rowY + rowHeight / 2),
                            anchor: .leading
                        )
                        ctx.draw(
                            Text("\(i + 1)").font(.system(size: 13, weight: .semibold))
                                           .foregroundStyle(Color.blue),
                            at: CGPoint(x: 34, y: rowY + rowHeight / 2),
                            anchor: .center
                        )
                    }
                }
                .frame(width: size.width, height: totalHeight)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = -$0 }
            .layerEffect(
                ShaderLibrary.redBottom(
                    .float2(size.width, size.height)
                ),
                maxSampleOffset: CGSize(width: 0, height: size.height * 0.08)
            )
        }
        .navigationTitle("Red Bottom")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground))
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        RedBottomListDemo()
    }
}
