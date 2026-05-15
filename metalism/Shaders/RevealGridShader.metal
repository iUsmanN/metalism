//
//  RevealGridShader.metal
//  metalism
//
//  colorEffect: divides the view into rows x cols cells, each fading in
//  from black to the original colour with a random staggered delay.
//  revealGridSequential: same but cells appear in strict left-to-right,
//  top-to-bottom reading order.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 revealGrid(float2 position,
                 half4  color,
                 float2 size,
                 float  progress,   // 0 = all hidden, 1 = all visible
                 float  cols,
                 float  rows)
{
    // position is local to the view: (0,0) = top-left, size = bottom-right
    float2 uv = position / size;

    int col  = int(uv.x * cols);
    int row  = int(uv.y * rows);
    float cellIdx = float(row) * cols + float(col);

    // Pseudo-random delay per cell
    float h = fract(sin(cellIdx * 127.1 + cols * 311.7 + rows * 74.3) * 43758.5453);

    // Each cell fades in over 40% of the progress range, staggered by h across the first 60%
    float stagger = 0.6;
    float window  = 0.4;
    float delay   = h * stagger;
    float local   = saturate((progress - delay) / window);
    float revealed = smoothstep(0.0, 1.0, local);

    half3 rgb = mix(half3(0.0h), color.rgb, half(revealed));
    return half4(rgb, color.a);
}

[[ stitchable ]]
half4 revealGridDiamond(float2 position,
                        half4  color,
                        float2 size,
                        float  progress,
                        float  cols,
                        float  rows)
{
    float2 uv = position / size;

    float col = float(int(uv.x * cols));
    float row = float(int(uv.y * rows));

    // Centre of the grid in cell units
    float cx = (cols - 1.0) * 0.5;
    float cy = (rows - 1.0) * 0.5;

    // Manhattan distance from centre produces diamond rings
    float dist    = abs(col - cx) + abs(row - cy);
    float maxDist = cx + cy;   // distance to corner

    float norm    = maxDist > 0.0 ? dist / maxDist : 0.0;

    float stagger  = 0.6;
    float delay    = norm * stagger;
    float window   = 0.4;
    float local    = saturate((progress - delay) / window);
    float revealed = smoothstep(0.0, 1.0, local);

    half3 rgb = mix(half3(0.0h), color.rgb, half(revealed));
    return half4(rgb, color.a);
}

[[ stitchable ]]
half4 revealGridSequential(float2 position,
                           half4  color,
                           float2 size,
                           float  progress,   // 0 = all hidden, 1 = all visible
                           float  cols,
                           float  rows)
{
    float2 uv = position / size;

    int col  = int(uv.x * cols);
    int row  = int(uv.y * rows);
    float cellIdx = float(row) * cols + float(col);
    float total   = cols * rows;

    // Each cell gets an equal slice of the stagger window (60% of progress)
    float stagger = 0.6;
    float norm    = total > 1.0 ? cellIdx / (total - 1.0) : 0.0;
    float delay   = norm * stagger;
    float window  = 0.4;
    float local   = saturate((progress - delay) / window);
    float revealed = smoothstep(0.0, 1.0, local);

    half3 rgb = mix(half3(0.0h), color.rgb, half(revealed));
    return half4(rgb, color.a);
}
