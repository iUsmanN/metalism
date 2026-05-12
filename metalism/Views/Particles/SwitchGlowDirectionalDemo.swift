//
//  SwitchGlowDirectionalDemo.swift
//  metalism
//
//  Extends SwitchGlowDemo with a direction picker:
//    • Radial  — ring expands from centre (circle → square)
//    • Horizontal — vertical waveline sweeps left → right
//    • Vertical   — horizontal waveline sweeps top → bottom
//

import SwiftUI

enum WaveDirection: String, CaseIterable {
    case radial     = "Radial"
    case horizontal = "Left → Right"
    case vertical   = "Top → Bottom"

    var shaderValue: Float {
        switch self {
        case .radial:     return 0
        case .horizontal: return 1
        case .vertical:   return 2
        }
    }
}

struct SwitchGlowDirectionalDemo: View {

    @State private var isOn:           Bool          = false
    @State private var triggerTime:    Date?         = nil
    @State private var cardSize:       CGSize        = .zero
    @State private var direction:      WaveDirection = .horizontal
    @State private var ringWidth:      Float         = 50
    @State private var expandDuration: Float         = 2.5
    @State private var aberrationStr:  Float         = 0.44
    @State private var blurStr:        Float         = 0.52

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        HStack {
            Text("\(label): \(format)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // ── Card with shader ──────────────────────────────────────────
                TimelineView(.animation) { timeline in
                    let elapsed = triggerTime.map {
                        Float(timeline.date.timeIntervalSince($0))
                    } ?? -1

                    // Travel distance depends on direction
                    let travelDist: Float = {
                        switch direction {
                        case .radial:
                            return Float(sqrt(cardSize.width  * cardSize.width +
                                             cardSize.height * cardSize.height)) / 2
                        case .horizontal:
                            return Float(cardSize.width)
                        case .vertical:
                            return Float(cardSize.height)
                        }
                    }()

                    let progress   = elapsed < 0 ? Float(-1) : min(elapsed / expandDuration, 1.0)
                    let ringRadius = max(progress, 0) * travelDist
                    let squareness = max(progress, 0)
                    // Hold at full strength for the whole travel, then snap off
                    let fadeDuration: Float = 0.15   // quick fade at the very end
                    let fadeStart = expandDuration - fadeDuration
                    let strength: Float = elapsed < 0 ? 0 :
                        elapsed < fadeStart ? 1.0 :
                        max(0, 1.0 - (elapsed - fadeStart) / fadeDuration)

                    GeometryReader { geo in
                        cardCanvas(size: geo.size)
                            .layerEffect(
                                ShaderLibrary.switchGlowDirectional(
                                    .float2(Float(geo.size.width  / 2),
                                            Float(geo.size.height / 2)),
                                    .float(ringRadius),
                                    .float(ringWidth),
                                    .float(squareness),
                                    .float(strength),
                                    .float(direction.shaderValue),
                                    .float(Float(geo.size.width)),
                                    .float(Float(geo.size.height)),
                                    .float(aberrationStr),
                                    .float(blurStr)
                                ),
                                maxSampleOffset: CGSize(
                                    width:  Double(ringWidth + 12),
                                    height: Double(ringWidth + 12)
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                            .onAppear { cardSize = geo.size }
                    }
                    .frame(height: 320)
                    .padding(.horizontal, 28)
                }

                // ── Controls ──────────────────────────────────────────────────
                VStack(spacing: 12) {
                    // Direction picker
                    HStack(spacing: 0) {
                        ForEach(WaveDirection.allCases, id: \.self) { d in
                            Button {
                                direction = d
                            } label: {
                                Text(d.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(direction == d ? .white : .secondary)
                                    .background(
                                        direction == d
                                            ? Color.indigo
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.07), radius: 8, y: 3)

                    // Toggle
                    HStack(spacing: 16) {
                        Text(isOn ? "On" : "Off")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isOn ? Color.indigo : Color.secondary)
                            .animation(.easeInOut(duration: 0.2), value: isOn)

                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .tint(.indigo)
                            .onChange(of: isOn) { _, _ in
                                triggerTime = Date.now
                            }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
                    .padding(.horizontal, 60)

                    // Sliders
                    VStack(spacing: 6) {
                        sliderRow("Band width",   value: Binding(get: { CGFloat(ringWidth) },      set: { ringWidth = Float($0) }),      in: 10...120, format: "\(Int(ringWidth))pt")
                        sliderRow("Duration",     value: Binding(get: { CGFloat(expandDuration) }, set: { expandDuration = Float($0) }), in: 0.2...2.5, format: String(format: "%.1fs", expandDuration))
                        sliderRow("Aberration",   value: Binding(get: { CGFloat(aberrationStr) },  set: { aberrationStr = Float($0) }),  in: 0...3, format: String(format: "%.2f", aberrationStr))
                        sliderRow("Blur",         value: Binding(get: { CGFloat(blurStr) },        set: { blurStr = Float($0) }),        in: 0...3, format: String(format: "%.2f", blurStr))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                    .padding(.horizontal, 16)
                }

                Spacer()
            }
        }
    }

    // MARK: - Card canvas — 5×5 grid, white background, black text

    private let gridLabels: [[String]] = [
        ["W","A","V","E","S","H","I","F","T","X"],
        ["B","L","U","R","G","L","O","W","F","A"],
        ["D","E","P","T","H","S","P","A","R","K"],
        ["R","I","P","P","L","E","F","L","A","R"],
        ["P","R","I","S","M","W","A","R","P","Z"],
        ["H","A","L","O","B","E","A","M","S","Q"],
        ["L","E","N","S","D","R","I","F","T","J"],
        ["G","L","I","N","T","B","L","O","O","M"],
        ["E","C","H","O","F","A","D","E","V","K"],
        ["S","U","R","G","E","T","R","A","C","E"],
    ]

    private func cardCanvas(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            let cols = 10
            let rows = 10
            let divider: CGFloat = 1
            let cellW = (canvasSize.width  - divider * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (canvasSize.height - divider * CGFloat(rows - 1)) / CGFloat(rows)

            // White background
            ctx.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.white)
            )

            for row in 0..<rows {
                for col in 0..<cols {
                    let originX = CGFloat(col) * (cellW + divider)
                    let originY = CGFloat(row) * (cellH + divider)
                    let cellRect = CGRect(x: originX, y: originY, width: cellW, height: cellH)

                    // Cell background (slightly off-white on alternating cells)
                    let isAlt = (row + col) % 2 == 1
                    ctx.fill(
                        Path(cellRect),
                        with: .color(isAlt ? Color(white: 0.96) : .white)
                    )

                    // Label centred in cell
                    let label = gridLabels[row][col]
                    ctx.draw(
                        Text(label)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.75)),
                        at: CGPoint(x: originX + cellW / 2, y: originY + cellH / 2),
                        anchor: .center
                    )
                }
            }

            // Divider lines
            var dividers = Path()
            for col in 1..<cols {
                let x = CGFloat(col) * (cellW + divider) - divider
                dividers.move(to: CGPoint(x: x, y: 0))
                dividers.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            for row in 1..<rows {
                let y = CGFloat(row) * (cellH + divider) - divider
                dividers.move(to: CGPoint(x: 0, y: y))
                dividers.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            ctx.stroke(dividers, with: .color(Color(white: 0.82)), lineWidth: divider)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}



#Preview {
    SwitchGlowDirectionalDemo()
}
