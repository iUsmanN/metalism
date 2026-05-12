//
//  SwitchGlowDirectionalShader.metal
//  metalism
//
//  Extends switchGlow with a direction parameter:
//    direction == 0 → original radial ring (circle → square)
//    direction == 1 → horizontal sweep: wave travels left → right as a vertical line
//    direction == 2 → vertical sweep:   wave travels top  → bottom as a horizontal line
//
//  For directional modes, `ringRadius` is the position of the wavefront along
//  the sweep axis (0 = start edge, full card width/height = end edge).
//  `origin` is the start edge coordinate on that axis.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

constant float sgdWeights[5] = { 0.0625, 0.25, 0.375, 0.25, 0.0625 };

[[ stitchable ]]
half4 switchGlowDirectional(float2 position,
                             SwiftUI::Layer layer,
                             float2 centre,         // card centre (used for radial mode)
                             float  ringRadius,     // wavefront position along sweep axis
                             float  ringWidth,      // half-width of effect band
                             float  squareness,     // 0=circle, 1=square (radial mode only)
                             float  strength,       // overall effect strength (fades to 0)
                             float  direction,      // 0=radial, 1=horizontal, 2=vertical
                             float  cardWidth,      // full card width in pts
                             float  cardHeight,     // full card height in pts
                             float  aberrationStr,  // chromatic aberration multiplier
                             float  blurStr)        // blur amount multiplier
{
    if (strength < 0.001) {
        return layer.sample(position);
    }

    float distToRing;
    float2 dir = float2(0.0);

    if (direction < 0.5) {
        // ── Radial mode (original) ────────────────────────────────────────────
        float2 delta     = position - centre;
        float euclidean  = length(delta);
        float chebyshev  = max(abs(delta.x), abs(delta.y));
        float dist       = mix(euclidean, chebyshev, squareness);
        distToRing       = abs(dist - ringRadius);

        if (euclidean > 0.5) {
            float2 euclidDir = delta / euclidean;
            float2 chebyDir  = delta / max(chebyshev, 0.001);
            dir = normalize(mix(euclidDir, chebyDir, squareness));
        }

    } else if (direction < 1.5) {
        // ── Horizontal sweep: wave travels left → right ───────────────────────
        // Wavefront is a vertical line at x = ringRadius
        float wavefrontX = ringRadius;
        distToRing       = abs(position.x - wavefrontX);

        // Aberration along the X axis (direction of travel)
        dir = float2(1.0, 0.0);

    } else {
        // ── Vertical sweep: wave travels top → bottom ─────────────────────────
        // Wavefront is a horizontal line at y = ringRadius
        float wavefrontY = ringRadius;
        distToRing       = abs(position.y - wavefrontY);

        // Aberration along the Y axis (direction of travel)
        dir = float2(0.0, 1.0);
    }

    // Early exit outside the ring band
    if (distToRing >= ringWidth) {
        return layer.sample(position);
    }

    // Smooth falloff within the band — peak at the wavefront
    float t         = 1.0 - smoothstep(0.0, ringWidth, distToRing);
    t               = t * t;
    float magnitude = t * strength;

    // Chromatic aberration along travel direction
    float aberration = magnitude * 8.0 * aberrationStr;
    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    float blurStep = magnitude * 2.5 * blurStr;

    float3 blurred  = float3(0.0);
    float  weightSum = 0.0;

    for (int i = 0; i < 5; i++) {
        float ox = (float(i) - 2.0) * blurStep;
        for (int j = 0; j < 5; j++) {
            float oy = (float(j) - 2.0) * blurStep;
            float2 offset = float2(ox, oy);
            float  w      = sgdWeights[i] * sgdWeights[j];

            blurred.r  += float(layer.sample(rPos + offset).r) * w;
            blurred.g  += float(layer.sample(gPos + offset).g) * w;
            blurred.b  += float(layer.sample(bPos + offset).b) * w;
            weightSum  += w;
        }
    }

    half4 base   = layer.sample(position);
    half3 result = half3(blurred / max(weightSum, 0.0001));
    return half4(result, base.a);
}
