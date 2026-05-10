//
//  PixelateBottomShader.metal
//  metalism
//
//  layerEffect: bottom 40% of the view has a horizontal stretch effect.
//  Stretch amount grows from 0 at the zone top to maximum at the bottom.
//  Chromatic aberration also scales with stretch intensity.
//  Padding on left, right, and bottom edges is left unaffected.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 pixelateBottom(float2 position,
                     SwiftUI::Layer layer,
                     float2 size,
                     float  time)
{
    float padH = 28.0;
    float padB = 1.0;

    float ny = position.y / size.y;
    float nx = position.x / size.x;

    if (position.x < padH || position.x > size.x - padH) {
        return layer.sample(position);
    }
    if (position.y > size.y - padB) {
        return layer.sample(position);
    }

    float zoneStart = 0.60;
    if (ny < zoneStart) {
        return layer.sample(position);
    }

    float t = (ny - zoneStart) / (1.0 - zoneStart);   // 0→1 within zone

    // ── Horizontal stretch ────────────────────────────────────────────────────
    // Pixels are pulled toward the horizontal centre — sample from a contracted
    // X range. stretch factor grows quadratically: 1 at top of zone → maxStretch at bottom.
    float maxStretch = 2.8;
    float stretch    = 1.0 + t * t * (maxStretch - 1.0);

    float centreX    = 0.5;
    float stretchedNX = centreX + (nx - centreX) / stretch;
    float2 sampleBase = float2(stretchedNX * size.x, position.y);

    // ── Chromatic aberration (horizontal, scales with t) ──────────────────────
    float aberration = t * t * 20.0;   // 0→20px at bottom

    half r = layer.sample(sampleBase + float2( aberration, 0.0)).r;
    half g = layer.sample(sampleBase).g;
    half b = layer.sample(sampleBase + float2(-aberration, 0.0)).b;
    half a = layer.sample(sampleBase).a;

    return half4(r, g, b, a);
}
