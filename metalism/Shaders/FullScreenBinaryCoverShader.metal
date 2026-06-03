//
//  FullScreenBinaryCoverShader.metal
//  metalism
//
//  Renders the underlying content as filled squares (bright) and circles (dark)
//  based on pixel luminance. Individual cells reveal at random intervals via
//  a revealProgress uniform swept 0→1.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── SDF helpers ──────────────────────────────────────────────────────────────

// "." : filled circle sized to fill the cell
static float sdtDot(float2 uv) {
    return length(uv) - 0.42;
}

// "■" : filled square
static float sdtSlash(float2 uv) {
    float2 q = abs(uv) - 0.42;
    return max(q.x, q.y);
}

// ── Character grid colour at an arbitrary screen position ────────────────────
// Returns float4: rgb = colour, a = 1 for opaque cell, 0 for transparent (dot background)
static float3 applySaturation(float3 col, float sat) {
    float luma = dot(col, float3(0.299, 0.587, 0.114));
    return mix(float3(luma), col, sat);
}

static float4 charGridColor(float2 samplePos,
                             SwiftUI::Layer layer,
                             float scrollOffset,
                             float cutoff,
                             float contrast,
                             float sat)
{
    float cellSize = 4.0;
    float2 scrolled           = samplePos + float2(0.0, scrollOffset);
    float2 cellIdx            = floor(scrolled / cellSize);
    float2 cellCentreScrolled = (cellIdx + 0.5) * cellSize;
    float2 cellCentreScreen   = cellCentreScrolled - float2(0.0, scrollOffset);

    // 4-point sampling — track both luma and colour so we can pick the brightest sample
    float halfC = cellSize * 0.45;
    float3 luma3 = float3(0.299, 0.587, 0.114);
    float2 o0 = float2(-halfC, -halfC), o1 = float2( halfC, -halfC);
    float2 o2 = float2(-halfC,  halfC), o3 = float2( halfC,  halfC);
    float3 c0 = float3(layer.sample(cellCentreScreen + o0).rgb);
    float3 c1 = float3(layer.sample(cellCentreScreen + o1).rgb);
    float3 c2 = float3(layer.sample(cellCentreScreen + o2).rgb);
    float3 c3 = float3(layer.sample(cellCentreScreen + o3).rgb);
    float  l0 = dot(c0, luma3), l1 = dot(c1, luma3);
    float  l2 = dot(c2, luma3), l3 = dot(c3, luma3);
    float  luma = max(max(l0, l1), max(l2, l3));

    // Pick the colour of the brightest sample point
    float3 brightColor = c0;
    if (l1 >= luma) brightColor = c1;
    if (l2 >= luma) brightColor = c2;
    if (l3 >= luma) brightColor = c3;

    float t = saturate((luma - cutoff) * contrast + 0.5);

    float2 cellUV   = (scrolled - cellCentreScrolled) / (cellSize * 0.5);  // -1..1
    bool   isSquare = (t > 0.5);

    if (isSquare) {
        float  d      = sdtSlash(cellUV * 0.95);
        float  aa     = fwidth(d);
        float  filled = 1.0 - smoothstep(-aa, aa, d);
        float3 pixelColor = applySaturation(brightColor, sat);
        float3 bgColor    = float3(0.04, 0.04, 0.04);
        float3 col        = mix(bgColor, pixelColor, filled);
        return float4(col, 1.0);
    } else {
        // "." → fully transparent: show original pixel through
        return float4(0.0, 0.0, 0.0, 0.0);
    }
}

// ── Per-cell hash for random reveal ──────────────────────────────────────────
static float cellHash(float2 idx) {
    return fract(sin(dot(idx, float2(127.1, 311.7))) * 43758.5453);
}

// ── Main shader ───────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 fullScreenBinaryCover(float2 position,
                             SwiftUI::Layer layer,
                             float2 centre,       // unused — kept for ABI compat
                             float  radius,       // unused — kept for ABI compat
                             float  ringWidth,    // unused — kept for ABI compat
                             float  cutoff,       // luma threshold 0..1
                             float  contrast,     // threshold sharpness
                             float  scrollOffset,   // scroll position
                             float  revealProgress, // 0 = hidden, 1 = visible
                             float  saturation)     // colour saturation multiplier
{
    // Effect fully disabled — return original with no shader work
    if (revealProgress <= 0.0) {
        return layer.sample(position);
    }

    // ── Per-cell random reveal ────────────────────────────────────────────────
    float cellSize   = 4.0;
    float2 scrolled2 = position + float2(0.0, scrollOffset);
    float2 cellIdx   = floor(scrolled2 / cellSize);
    float  h         = cellHash(cellIdx);
    float  cellVis   = smoothstep(h - 0.04, h + 0.04, revealProgress);

    half4  original = layer.sample(position);
    float4 baseChar = charGridColor(position, layer, scrollOffset, cutoff, contrast, saturation);

    // For dot cells (alpha=0), show original. For square cells (alpha=1), show the char grid.
    // cellVis animates both in together as revealProgress sweeps past each cell's threshold.
    float  charAlpha = baseChar.a * cellVis;
    float3 result    = mix(float3(original.rgb), baseChar.rgb, charAlpha);
    return half4(half3(result), original.a);
}
