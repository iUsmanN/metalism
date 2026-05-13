//
//  VerticalStretchShader.metal
//  metalism
//
//  layerEffect: bottom zone stretches vertically with chromatic aberration
//  and saturation control. All driven by a smooth t² curve.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 verticalStretch(float2 position,
                      SwiftUI::Layer layer,
                      float2 size,
                      float  warpAmt,       // max stretch multiplier (e.g. 2.6)
                      float  saturation)    // 0 = greyscale, 1 = normal, 2 = vivid
{
    float ny = position.y / size.y;

    float zoneStart = 0.70;
    if (ny < zoneStart) {
        return layer.sample(position);
    }

    // t: 0 at zone boundary, 1 at very bottom
    float t  = (ny - zoneStart) / (1.0 - zoneStart);
    float t2 = t * t;

    // Vertical stretch
    float stretch  = 1.0 + t2 * (warpAmt - 1.0);
    float zoneTopY = zoneStart * size.y;
    float localY   = position.y - zoneTopY;
    float2 samplePos = float2(position.x, zoneTopY + localY / stretch);

    half4 c = layer.sample(samplePos);

    // Saturation fades from full at zone top (t=0) to zero at zone bottom (t=1)
    float localSat = saturation * (1.0 - t);
    half luma = dot(c.rgb, half3(0.299h, 0.587h, 0.114h));
    c.rgb = mix(half3(luma), c.rgb, half(localSat));

    return c;
}
