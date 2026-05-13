//
//  RedGradientShader.metal
//  metalism
//
//  colorEffect that overlays a red gradient on the bottom 20% of the view.
//  Fully transparent at the 80% mark, full red tint at the very bottom.
//  Extends into safe area when the view does.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 redGradient(float2 position,
                  half4  color,
                  float2 size)
{
    float normY = position.y / size.y;

    // t: 0 at 80% height, ramps to 1 at 100%
    float t = smoothstep(0.80, 1.0, normY);

    // Blend original colour toward red
    half3 red    = half3(1.0h, 0.0h, 0.0h);
    half3 result = mix(color.rgb, red, half(t));

    return half4(result, color.a);
}
