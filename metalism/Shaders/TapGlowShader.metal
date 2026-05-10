//
//  TapGlowShader.metal
//  metalism
//
//  layerEffect that applies blur + chromatic aberration centred on a tap point.
//  Both effects share the same radial falloff — strongest at centre, zero at radius.
//  Chromatic aberration splits R/G/B radially outward; blur softens each channel.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 tapGlow(float2 position,
              SwiftUI::Layer layer,
              float2 touch,
              float  radius,
              float  strength)
{
    float2 delta = position - touch;
    float  dist  = length(delta);

    // Smooth radial falloff: 1 at centre, 0 at radius
    float t = 1.0 - smoothstep(0.0, radius, dist);

    // Shared effect magnitude — blur radius and aberration offset both use this
    float magnitude = t * strength;

    // Radial direction from touch (normalised); fallback to zero at exact centre
    float2 dir = (dist > 0.5) ? (delta / dist) : float2(0.0);

    // Chromatic aberration: R pulled outward, B pulled inward, G stays
    float aberration = magnitude * 14.0;
    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    // Gaussian blur per channel — blur radius matches aberration scale
    float blurRadius = magnitude * 18.0;
    int   taps       = 9;
    float halfTaps   = float(taps / 2);

    float3 blurred   = float3(0.0);
    float  weightSum = 0.0;

    for (int i = 0; i < taps; i++) {
        for (int j = 0; j < taps; j++) {
            float ox = (float(i) - halfTaps) * blurRadius / halfTaps;
            float oy = (float(j) - halfTaps) * blurRadius / halfTaps;
            float2 offset = float2(ox, oy);

            float sigma = blurRadius / 2.0 + 0.001;
            float w = exp(-(ox * ox + oy * oy) / (2.0 * sigma * sigma));

            blurred.r  += float(layer.sample(rPos + offset).r) * w;
            blurred.g  += float(layer.sample(gPos + offset).g) * w;
            blurred.b  += float(layer.sample(bPos + offset).b) * w;
            weightSum  += w;
        }
    }

    half4 base  = layer.sample(position);
    half3 result = (weightSum > 0.0)
        ? half3(blurred / weightSum)
        : base.rgb;

    return half4(result, base.a);
}
