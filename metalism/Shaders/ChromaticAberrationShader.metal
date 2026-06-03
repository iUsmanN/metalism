#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Radial chromatic aberration applied to the entire view.
/// R is pushed outward from centre, B is pushed inward.
///
/// - centre:   centre of the view in pixel coords
/// - progress: 0.0 = no effect, 1.0 = full effect
[[ stitchable ]] half4 chromaticAberration(
    float2 position,
    SwiftUI::Layer layer,
    float2 centre,
    float  progress
) {
    if (progress < 0.001) {
        return layer.sample(position);
    }

    float2 delta = position - centre;
    float  dist  = length(delta);
    float2 dir   = (dist > 0.5) ? (delta / dist) : float2(1.0, 0.0);

    float  aberration = progress * 10.0;
    float2 rPos       = position + dir * aberration;
    float2 bPos       = position - dir * aberration;

    half4 rSample = layer.sample(rPos);
    half4 gSample = layer.sample(position);
    half4 bSample = layer.sample(bPos);

    return half4(rSample.r, gSample.g, bSample.b, gSample.a);
}
