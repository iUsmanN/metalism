//
//  BottomWaveVerticalShader.metal
//  metalism
//
//  colorEffect: Same animating sine wave as BottomWaveShader but the
//  gradient runs vertically — full brightness at the wave centre line
//  (ny ≈ 0.5) fading to zero at the top and bottom edges of the panel.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 bottomWaveVertical(float2 position,
                         half4  color,
                         float2 size,
                         float  time,
                         float  direction,   // 1.0 = left→right, -1.0 = right→left
                         float3 tint)        // RGB colour of this wave
{
    float nx = position.x / size.x;   // 0 → 1 left to right
    float ny = position.y / size.y;   // 0 → 1 top to bottom

    // Sine wave centre (in normalised Y): scrolls in the given direction via time
    float frequency = 2.0;
    float speed     = 1.2;
    float amplitude = 0.05;
    float baseline  = 0.5;

    float waveCentreY = baseline + amplitude * sin(nx * frequency * 6.28318 - direction * time * speed);

    // Signed distance from the wave line in Y (normalised)
    float distY = ny - waveCentreY;

    // ── Wave line glow ────────────────────────────────────────────────────────
    // lineWidth pulses between 0.04 and 0.28 via a cosine that travels with the wave
    float lineWidth = 0.16 + 0.12 * cos(nx * 1.0 * 6.28318 - direction * time * speed * 0.08);
    float lineSDF   = abs(distY) - lineWidth * 0.5;
    float lineGlow  = exp(-max(lineSDF, 0.0) * 80.0) * 0.35;   // tight core

    // Bloom: stacked exponential halos, each wider and dimmer
    lineGlow += exp(-max(lineSDF, 0.0) * 18.0) * 0.25;   // inner bloom
    lineGlow += exp(-max(lineSDF, 0.0) *  7.0) * 0.15;   // mid bloom
    lineGlow += exp(-max(lineSDF, 0.0) *  2.5) * 0.08;   // outer bloom
    lineGlow += exp(-max(lineSDF, 0.0) *  0.8) * 0.04;   // wide atmospheric glow
    lineGlow = saturate(lineGlow);

    // ── Fill beneath the wave ─────────────────────────────────────────────────
    float fillT = smoothstep(0.0, 0.55, distY);
    float fill  = fillT * 0.18;

    // ── Vertical gradient: full at wave centre, zero at top and bottom ────────
    // Bell curve centred on waveCentreY
    float distFromWave = abs(ny - waveCentreY);
    float vertGrad = 1.0 - smoothstep(0.0, 0.5, distFromWave * 1.2);
    vertGrad = vertGrad * vertGrad;   // squared for tighter falloff

    // ── Compose ───────────────────────────────────────────────────────────────
    float brightness = saturate((lineGlow + fill) * vertGrad);

    float3 rgb = brightness * tint;
    return half4(half(rgb.r), half(rgb.g), half(rgb.b), 1.0h);
}
