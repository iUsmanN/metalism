//
//  WaterWaveShader.metal
//  metalism
//
//  colorEffect: water cross-section with a single sine wave surface.
//  Sky above, deep-water gradient below, thin foam at the waterline.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 waterWave(float2 position,
                half4  currentColor,
                float2 size,
                float  time)
{
    float nx = position.x / size.x;   // 0 → 1 left to right
    float ny = position.y / size.y;   // 0 → 1 top to bottom

    // Single sine wave — one full cycle across the screen, subtle amplitude
    float amplitude = 0.04;           // 4% of screen height
    float centreY   = 0.50;
    float surfaceNY = centreY + amplitude * sin(nx * 6.28318 - time * 1.4);

    float belowSurface = ny - surfaceNY;

    // Sky
    if (belowSurface < -0.002) {
        float skyT = 1.0 - ny;
        float3 skyTop    = float3(0.53, 0.76, 0.92);
        float3 skyBottom = float3(0.82, 0.93, 0.98);
        float3 skyCol    = mix(skyBottom, skyTop, skyT * skyT);
        return half4(half3(skyCol), 1.0);
    }

    // Thin foam line at the surface
    float foamWidth = 0.006;
    if (belowSurface < foamWidth) {
        float alpha = 1.0 - (belowSurface / foamWidth);
        return half4(half3(0.95, 0.97, 1.0), half(alpha * 0.85));
    }

    // Water body — shallow teal → deep navy
    float maxDepth = 1.0 - surfaceNY;
    float depth    = saturate((ny - surfaceNY) / max(maxDepth, 0.001));
    float3 shallow = float3(0.05, 0.52, 0.62);
    float3 deep    = float3(0.01, 0.07, 0.22);
    float3 waterCol = mix(shallow, deep, depth * depth);

    return half4(half3(saturate(waterCol)), 1.0);
}
