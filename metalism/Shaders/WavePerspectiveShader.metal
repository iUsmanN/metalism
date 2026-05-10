//
//  WavePerspectiveShader.metal
//  metalism
//
//  layerEffect: a sine wave flows left to right across the entire view.
//  The wave is a horizontal band that undulates in Y as it moves.
//  - The effect covers the full view height
//  - Closer to camera (bottom) → more chromatic aberration, less opacity
//  - Further away (top)        → less aberration, full opacity
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 wavePerspective(float2 position,
                      SwiftUI::Layer layer,
                      float2 size,
                      float  time)
{
    float nx = position.x / size.x;   // 0→1 left to right
    float ny = position.y / size.y;   // 0→1 top to bottom

    // ── Wave: sine in Y scrolling left to right ───────────────────────────────
    // The wave centreline for this pixel's row is a sine of (nx - time)
    // This makes the wave move from left to right
    float speed     = 0.4;
    float frequency = 2.0;   // number of full cycles across the screen

    // Wave centreline at this X position — undulates in Y
    float waveCentreY = 0.5 + 0.38 * sin(nx * frequency * 6.28318 - time * speed);

    // Distance from this pixel's Y to the wave centreline
    float dy = ny - waveCentreY;

    // ── Perspective band width ────────────────────────────────────────────────
    // Band grows thicker toward the bottom (near camera)
    float nearness = ny;   // 0=top/far, 1=bottom/near
    float bandHalf = mix(0.12, 0.42, nearness * nearness);

    // Only apply effect inside the band
    if (abs(dy) > bandHalf) {
        return layer.sample(position);
    }

    // ── Falloff (1 at centreline, 0 at edge) ─────────────────────────────────
    float t = 1.0 - smoothstep(0.0, bandHalf, abs(dy));
    t = t * t;

    // ── Depth-based modulation ────────────────────────────────────────────────
    float depthT     = nearness * nearness;
    float aberration = depthT * t * 30.0;          // px chromatic split, peaks at bottom
    float alpha      = (1.0 - depthT * 0.85) * t;  // fades near camera

    // Chromatic aberration splits vertically (perpendicular to wave travel)
    float2 dir = float2(0.0, sign(dy));

    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    // Sample channels with 20% brightness boost
    half r = min(layer.sample(rPos).r * 1.2h, 1.0h);
    half g = min(layer.sample(gPos).g * 1.2h, 1.0h);
    half b = min(layer.sample(bPos).b * 1.2h, 1.0h);

    half4 base   = layer.sample(position);
    half4 wavePx = half4(r, g, b, 1.0h);

    return mix(base, wavePx, half(alpha));
}
