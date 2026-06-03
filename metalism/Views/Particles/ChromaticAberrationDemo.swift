import SwiftUI

struct ChromaticAberrationDemo: View {
    @State private var counter: Int = 0
    @State private var progress: Float = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 48) {
                GeometryReader { geo in
                    Text("\(counter)")
                        .font(.system(size: 96, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layerEffect(
                            ShaderLibrary.chromaticAberration(
                                .float2(Float(geo.size.width  / 2),
                                        Float(geo.size.height / 2)),
                                .float(progress)
                            ),
                            maxSampleOffset: CGSize(width: 12, height: 12)
                        )
                }
                .frame(height: 160)

                Button {
                    counter += 1
                    triggerAberration()
                } label: {
                    Text("Increment")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Chromatic Aberration")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func triggerAberration() {
        withAnimation(.easeOut(duration: 0.1)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.5)) {
                progress = 0.0
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChromaticAberrationDemo()
    }
}
