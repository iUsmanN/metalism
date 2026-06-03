//
//  WrittenTextDemo.swift
//  metalism
//

import SwiftUI
import UIKit
import CoreText

// MARK: - Glyph path extraction

private func glyphPath(for character: Character, font: UIFont) -> CGPath? {
    let string = String(character)
    let font_ct = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)

    var glyph = CGGlyph()
    var uchar = (string.unicodeScalars.first?.value).map { UniChar($0) } ?? 0
    guard CTFontGetGlyphsForCharacters(font_ct, &uchar, &glyph, 1) else { return nil }

    return CTFontCreatePathForGlyph(font_ct, glyph, nil)
}

// MARK: - Animated glyph view

private struct GlyphStrokeView: UIViewRepresentable {
    let character: Character
    let progress:  CGFloat   // 0 = nothing, 1 = fully drawn

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove old layers
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let bounds = uiView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let fontSize = min(bounds.width, bounds.height) * 0.75
        let font = UIFont(name: "HelveticaNeue-UltraLight", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .ultraLight)

        guard let rawPath = glyphPath(for: character, font: font) else { return }

        // Flip and centre the glyph (CoreText is bottom-up)
        let pathBounds = rawPath.boundingBoxOfPath
        let scaleX = bounds.width  * 0.8 / pathBounds.width
        let scaleY = bounds.height * 0.8 / pathBounds.height
        let scale  = min(scaleX, scaleY)

        let scaledW = pathBounds.width  * scale
        let scaledH = pathBounds.height * scale
        let tx = (bounds.width  - scaledW) / 2 - pathBounds.minX * scale
        let ty = (bounds.height - scaledH) / 2 + pathBounds.maxY * scale   // flip Y

        var transform = CGAffineTransform(scaleX: scale, y: -scale)
            .translatedBy(x: tx / scale, y: -ty / scale)

        guard let finalPath = rawPath.copy(using: &transform) else { return }

        // Stroke layer — drawn along the path
        let strokeLayer = CAShapeLayer()
        strokeLayer.path        = finalPath
        strokeLayer.fillColor   = UIColor.clear.cgColor
        strokeLayer.strokeColor = UIColor.white.cgColor
        strokeLayer.lineWidth   = fontSize * 0.018
        strokeLayer.lineCap     = .round
        strokeLayer.lineJoin    = .round
        strokeLayer.strokeEnd   = progress

        uiView.layer.addSublayer(strokeLayer)
    }
}

// MARK: - Keyboard capture

private struct KeyboardCapture: UIViewRepresentable {
    var onCharacter: (Character) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCharacter: onCharacter) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.autocorrectionType    = .no
        field.autocapitalizationType = .none
        field.spellCheckingType     = .no
        field.delegate              = context.coordinator
        field.alpha                 = 0
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {}

    class Coordinator: NSObject, UITextFieldDelegate {
        let onCharacter: (Character) -> Void
        init(onCharacter: @escaping (Character) -> Void) { self.onCharacter = onCharacter }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            if let char = string.last { onCharacter(char) }
            textField.text = ""
            return false
        }
    }
}

// MARK: - Demo

struct WrittenTextDemo: View {

    @State private var currentChar: Character = "A"
    @State private var drawStart:   Date      = .now
    @State private var progress:    CGFloat   = 0
    private let drawDuration: Double = 1.2

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            KeyboardCapture { char in
                let upper = String(char).uppercased().first ?? char
                currentChar = upper
                drawStart   = .now
                progress    = 0
            }
            .frame(width: 0, height: 0)

            TimelineView(.animation) { tl in
                let elapsed = tl.date.timeIntervalSince(drawStart)
                let p = CGFloat(min(elapsed / drawDuration, 1.0))

                GlyphStrokeView(character: currentChar, progress: p)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Written Text")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WrittenTextDemo()
    }
}
