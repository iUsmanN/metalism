//
//  StretchBlurShader.metal
//  metalism
//
//  layerEffect: bottom 40% of the view has horizontal stretch + chromatic
//  aberration (same as PixelateBottomShader) plus a directional blur that
//  scales with the stretch amount. Blur is applied along the X axis,
//  maximum at the bottom, zero at the zone boundary.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 stretchBlur(float2 position,
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
    float maxStretch  = 2.8;
    float stretch     = 1.0 + t * t * (maxStretch - 1.0);
    float centreX     = 0.5;
    float stretchedNX = centreX + (nx - centreX) / stretch;
    float2 sampleBase = float2(stretchedNX * size.x, position.y);

    // ── Directional horizontal blur scales with t² ────────────────────────────
    // maxBlur px spread at full t, 0 at t=0
    float maxBlur  = 18.0;
    float blurStep = t * t * maxBlur;

    float weights[5] = { 0.0625, 0.25, 0.375, 0.25, 0.0625 };

    // ── Chromatic aberration (scales with t) ──────────────────────────────────
    float aberration = t * t * 20.0;

    float3 blurredR = float3(0.0);
    float3 blurredG = float3(0.0);
    float3 blurredB = float3(0.0);
    float  wSum     = 0.0;

    for (int i = 0; i < 5; i++) {
        float ox = (float(i) - 2.0) * blurStep;
        float w  = weights[i];

        blurredR += float3(layer.sample(sampleBase + float2(ox + aberration, 0.0)).r) * w;
        blurredG += float3(layer.sample(sampleBase + float2(ox,              0.0)).g) * w;
        blurredB += float3(layer.sample(sampleBase + float2(ox - aberration, 0.0)).b) * w;
        wSum     += w;
    }

    half r = half(blurredR.r / wSum);
    half g = half(blurredG.g / wSum);
    half b = half(blurredB.b / wSum);

    return half4(r, g, b, 1);
}
