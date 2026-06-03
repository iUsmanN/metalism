//
//  WrittenTextShader.metal
//  metalism
//
//  layerEffect: reveals a letter as if being drawn by a pen,
//  sweeping diagonally top-left → bottom-right with ink bleed.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 writtenText(float2 position,
                  SwiftUI::Layer layer,
                  float2 size,
                  float  progress)   // 0 = nothing drawn, 1 = fully drawn
{
    float2 uv = position / size;

    // Diagonal sweep front: top-left (0,0) → bottom-right (1,1)
    // Add slight sine wobble to mimic natural pen movement
    float wobble = sin(uv.y * 12.0) * 0.018 + cos(uv.x * 8.0) * 0.012;
    float sweep  = (uv.x + uv.y) * 0.5 + wobble;

    // How far ahead of the front we allow pixels to show (ink bleed width)
    float bleedWidth = 0.08;
    float front      = progress * (1.0 + bleedWidth) - bleedWidth * 0.5;

    // Pixels behind the front are fully revealed
    // Pixels just ahead of the front bleed in softly (wet ink spreading)
    float revealMask = 1.0 - smoothstep(front - bleedWidth * 0.3, front + bleedWidth, sweep);

    // Sample the original letter pixel
    half4 color = layer.sample(position);

    // Ink darkness: leading edge is slightly darker/thicker (fresh ink)
    float edgeDark = smoothstep(front - bleedWidth, front, sweep);
    half3 inkColor = mix(color.rgb, half3(0.0h), half(edgeDark * 0.35h));

    // Apply reveal mask to alpha
    half alpha = color.a * half(revealMask);

    return half4(inkColor * alpha, alpha);
}
