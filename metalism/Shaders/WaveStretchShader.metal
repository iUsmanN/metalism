//
//  WaveStretchShader.metal
//  metalism
//
//  layerEffect: a wave sweeps left to right. As it passes each column,
//  the pixels in that column are vertically stretched — sampling from a
//  compressed/expanded Y range. Chromatic aberration and brightness boost
//  scale with depth (bottom = near camera = more effect, less opacity).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 waveStretch(float2 position,
                  SwiftUI::Layer layer,
                  float2 size,
                  float  time)
{
    float nx = position.x / size.x;   // 0→1 left to right
    float ny = position.y / size.y;   // 0→1 top to bottom

    // ── Wave front position ───────────────────────────────────────────────────
    // The wave sweeps left to right, looping with fract()
    float speed    = 0.18;
    float waveFront = fract(time * speed);   // 0→1 horizontal position of wave peak

    // Distance of this column from the wave front (signed, wrapping)
    float dx = nx - waveFront;
    // Wrap to [-0.5, 0.5] so the wave loops seamlessly
    dx = dx - round(dx);

    // ── Column influence ─────────────────────────────────────────────────────
    // Smooth bell curve: peak at dx=0 (wave front), zero at ±halfWidth
    float halfWidth = 0.18;
    float influence = 1.0 - smoothstep(0.0, halfWidth, abs(dx));
    influence = influence * influence * influence;

    if (influence < 0.001) {
        return layer.sample(position);
    }

    // ── Perspective depth scale ───────────────────────────────────────────────
    float nearness = ny;   // 0=top/far, 1=bottom/near
    float depthT   = nearness * nearness;

    // ── Horizontal stretch (column compression toward wave front) ────────────
    float maxStretch  = mix(0.18, 0.55, depthT);
    float stretch     = 1.0 + maxStretch * influence;
    float stretchedNX = waveFront + (nx - waveFront) / stretch;
    float2 sampleBase = float2(stretchedNX * size.x, position.y);

    // ── Refraction — displace the sample point based on wave gradient ─────────
    // The gradient of the bell curve gives a push: pixels ahead of the front
    // are pulled forward, pixels behind are pushed back, creating a lens warp.
    // gradient sign: negative before front, positive after
    float gradient      = -dx / max(abs(dx), 0.001) * influence;
    float refrStrength  = mix(6.0, 22.0, depthT);    // px of refraction offset
    float2 refrOffset   = float2(gradient * refrStrength, 0.0);
    sampleBase += refrOffset;

    // ── Chromatic aberration (horizontal split along travel direction) ────────
    float aberration = depthT * influence * 28.0;
    float2 rPos = sampleBase + float2( aberration, 0.0);
    float2 gPos = sampleBase;
    float2 bPos = sampleBase + float2(-aberration, 0.0);

    // ── Opacity fades near camera ─────────────────────────────────────────────
    float alpha = (1.0 - depthT * 0.85) * influence;

    // Sample with 20% brightness boost
    half r = min(layer.sample(rPos).r * 1.2h, 1.0h);
    half g = min(layer.sample(gPos).g * 1.2h, 1.0h);
    half b = min(layer.sample(bPos).b * 1.2h, 1.0h);

    half4 base   = layer.sample(position);
    half4 effect = half4(r, g, b, 1.0h);

    return mix(base, effect, half(alpha));
}
