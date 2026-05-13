//
//  BlobBinaryShader.metal
//  metalism
//
//  The full circle renders the underlying content as "/" and "." characters
//  based on pixel luminance. The cell grid tracks scroll position.
//  The outer 30% of the circle has a physics-based glass-ring warp applied
//  ON TOP of the character grid — bending, blurring and adding specular/caustic
//  highlights to the characters beneath.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── SDF helpers ──────────────────────────────────────────────────────────────

static float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    return length(pa - ba * h);
}

// "." : small filled circle
static float sdtDot(float2 uv) {
    return length(uv - float2(0.0, 0.28)) - 0.10;
}

// "/" : diagonal stroke
static float sdtSlash(float2 uv) {
    return sdSegment(uv, float2(-0.18, 0.30), float2(0.18, -0.30)) - 0.055;
}

// ── Character grid colour at an arbitrary screen position ────────────────────
// samplePos  — screen-space position to evaluate the character grid at
// layer      — the source layer (used for luma sampling)
// scrollOffset — vertical scroll offset to anchor grid to content
// cutoff / contrast — threshold params
static float3 charGridColor(float2 samplePos,
                             SwiftUI::Layer layer,
                             float scrollOffset,
                             float cutoff,
                             float contrast)
{
    float cellSize = 7.0;
    float2 scrolled           = samplePos + float2(0.0, scrollOffset);
    float2 cellIdx            = floor(scrolled / cellSize);
    float2 cellCentreScrolled = (cellIdx + 0.5) * cellSize;
    float2 cellCentreScreen   = cellCentreScrolled - float2(0.0, scrollOffset);

    // 4-point max-luma sampling so partial letter overlap registers as positive
    float halfC = cellSize * 0.25;
    float3 luma3 = float3(0.299, 0.587, 0.114);
    float l0 = dot(float3(layer.sample(cellCentreScreen + float2(-halfC,-halfC)).rgb), luma3);
    float l1 = dot(float3(layer.sample(cellCentreScreen + float2( halfC,-halfC)).rgb), luma3);
    float l2 = dot(float3(layer.sample(cellCentreScreen + float2(-halfC, halfC)).rgb), luma3);
    float l3 = dot(float3(layer.sample(cellCentreScreen + float2( halfC, halfC)).rgb), luma3);
    float luma = max(max(l0, l1), max(l2, l3));

    float t = saturate((luma - cutoff) * contrast + 0.5);

    float2 cellUV = (scrolled - cellCentreScrolled) / (cellSize * 0.5);  // -1..1
    float d = (t > 0.5) ? sdtSlash(cellUV * 0.95) : sdtDot(cellUV * 0.95);

    float aa     = fwidth(d);
    float filled = 1.0 - smoothstep(-aa, aa, d);

    float3 charColor = float3(1.0, 1.0, 1.0);
    float3 bgColor   = float3(0.04, 0.04, 0.04);
    return mix(bgColor, charColor, filled);
}

// ── Main shader ───────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 blobBinary(float2 position,
                 SwiftUI::Layer layer,
                 float2 centre,
                 float  radius,        // outer radius
                 float  ringWidth,     // unused (kept for ABI compat)
                 float  cutoff,        // luma threshold 0..1
                 float  contrast,      // threshold sharpness
                 float  scrollOffset)  // scroll position
{
    float2 delta = position - centre;
    float  dist  = length(delta);

    // Outside circle — untouched
    if (dist > radius) {
        return layer.sample(position);
    }

    float2 radial = (dist > 0.001) ? delta / dist : float2(0.0, 1.0);

    // ── Step 1: character grid at the current pixel ───────────────────────────
    float3 baseChar = charGridColor(position, layer, scrollOffset, cutoff, contrast);

    // Soft fade at circle boundary
    float circleMask = smoothstep(radius, radius - 4.0, dist);
    half4  original  = layer.sample(position);
    float3 withChars = mix(float3(original.rgb), baseChar, circleMask);

    // ── Step 2: glass-ring warp in the outer 30% — warps the character grid ──
    float glassRingWidth = radius * 0.30;
    float innerBound     = radius - glassRingWidth;

    if (dist < innerBound) {
        return half4(half3(withChars), original.a);
    }

    // u ∈ [0,1]: 0 = inner edge of glass ring, 1 = outer edge
    float u          = (dist - innerBound) / glassRingWidth;
    float thickness  = (cos(u * 6.28318) + 1.0) * 0.5;  // 1 at edges, 0 at mid
    float normalTilt = sin(u * 6.28318);                 // +1 inner → -1 outer

    // Refraction offset (bends the character grid beneath the glass)
    float2 refrOff    = radial * (normalTilt * 48.0);
    float2 thickOff   = -radial * thickness * 20.0;
    float2 sampleBase = position + refrOff + thickOff;

    // Chromatic aberration: sample character grid at R/G/B-offset positions
    float  caAmt = thickness * 10.0;
    float3 rCol  = charGridColor(sampleBase + radial * caAmt,  layer, scrollOffset, cutoff, contrast);
    float3 gCol  = charGridColor(sampleBase,                   layer, scrollOffset, cutoff, contrast);
    float3 bCol  = charGridColor(sampleBase - radial * caAmt,  layer, scrollOffset, cutoff, contrast);

    // Thickness-driven blur — accumulate blurred character samples
    float sigma = max(28.0 * thickness * 0.5, 0.5);
    float bStep = sigma * 0.6;

    float3 sumR = rCol, sumG = gCol, sumB = bCol;
    float  wT   = 1.0;

    for (int k = 1; k <= 5; k++) {
        float tk  = float(k);
        float wk  = exp(-(tk * tk) / (2.0 * sigma * sigma / (bStep * bStep)));
        float o   = tk * bStep;
        float2 px = float2(o, 0.0);
        float2 py = float2(0.0, o);

        sumR += (charGridColor(sampleBase + px + radial * caAmt, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - px + radial * caAmt, layer, scrollOffset, cutoff, contrast)) * wk;
        sumG += (charGridColor(sampleBase + px, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - px, layer, scrollOffset, cutoff, contrast)) * wk;
        sumB += (charGridColor(sampleBase + px - radial * caAmt, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - px - radial * caAmt, layer, scrollOffset, cutoff, contrast)) * wk;

        sumR += (charGridColor(sampleBase + py + radial * caAmt, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - py + radial * caAmt, layer, scrollOffset, cutoff, contrast)) * wk;
        sumG += (charGridColor(sampleBase + py, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - py, layer, scrollOffset, cutoff, contrast)) * wk;
        sumB += (charGridColor(sampleBase + py - radial * caAmt, layer, scrollOffset, cutoff, contrast)
               + charGridColor(sampleBase - py - radial * caAmt, layer, scrollOffset, cutoff, contrast)) * wk;

        wT += wk * 4.0;
    }

    float3 warped = float3(sumR.r / wT, sumG.g / wT, sumB.b / wT);

    // Scroll-rotating specular highlight
    float  scrollAngle = scrollOffset * 0.008;
    float  cosS = cos(scrollAngle), sinS = sin(scrollAngle);
    float2 baseLight   = normalize(float2(0.6, -0.8));
    float2 light       = float2(cosS * baseLight.x - sinS * baseLight.y,
                                sinS * baseLight.x + cosS * baseLight.y);
    float  spec        = pow(saturate(dot(radial, light)), 28.0) * thickness;
    float3 specColor   = spec * float3(1.0, 0.97, 0.90) * 0.55;

    // Caustic rim glow at glass edges
    float  edgeGlow = pow(thickness, 3.0) * 0.18;
    float3 caustic  = float3(edgeGlow);

    // Glass darkens slightly at thicker regions
    float3 glassResult = saturate(warped * (1.0 - thickness * 0.15) + specColor + caustic);

    // Blend glass warp over base characters with smooth inner/outer feather
    float innerFade = smoothstep(innerBound, innerBound + 6.0, dist);
    float outerFade = smoothstep(radius, radius - 4.0, dist);
    float glassMask = innerFade * outerFade;

    float3 blended = mix(withChars, glassResult, glassMask);
    return half4(half3(blended), original.a);
}
