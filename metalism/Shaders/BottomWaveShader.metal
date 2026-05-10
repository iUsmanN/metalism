//
//  BottomWaveShader.metal
//  metalism
//
//  colorEffect: Animating sine wave scrolling left to right.
//  Renders on the bottom overlay panel — black background with a glowing
//  white sine wave line and a soft vertical gradient fill beneath it.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 bottomWave(float2 position,
                 half4  color,
                 float2 size,
                 float  time)
{
    float nx = position.x / size.x;   // 0 → 1 left to right
    float ny = position.y / size.y;   // 0 → 1 top to bottom

    // Sine wave centre (in normalised Y): scrolls left-to-right via time
    float frequency = 2.0;
    float speed     = 1.2;
    float amplitude = 0.05;
    float baseline  = 0.5;

    float waveCentreY = baseline + amplitude * sin(nx * frequency * 6.28318 - time * speed);

    // Signed distance from the wave line in Y (normalised)
    float distY = ny - waveCentreY;

    // ── Wave line glow ────────────────────────────────────────────────────────
    float lineWidth = 0.018;
    float lineSDF   = abs(distY) - lineWidth * 0.5;
    float lineGlow  = exp(-max(lineSDF, 0.0) * 80.0);   // tight core line

    // Soft wide blur halo around the line — wider Gaussian envelope
    float lineBlur  = exp(-max(lineSDF, 0.0) * 10.0) * 0.45;  // broad soft glow
    lineGlow = saturate(lineGlow + lineBlur);

    // ── Fill beneath the wave (gradient from wave down) ───────────────────────
    float fillT = smoothstep(0.0, 0.55, distY);          // fades toward bottom
    float fill  = fillT * 0.18;

    // ── Horizontal gradient: full at centre (nx=0.5), zero at edges ──────────
    // Smooth bell curve peaking at nx=0.5
    float centreGrad = 1.0 - smoothstep(0.0, 0.5, abs(nx - 0.5) * 2.0);
    centreGrad = centreGrad * centreGrad;   // squared for a tighter falloff

    // ── Compose ───────────────────────────────────────────────────────────────
    float brightness = saturate((lineGlow + fill) * centreGrad);

    return half4(half(brightness), half(brightness), half(brightness), 1.0h);
}
