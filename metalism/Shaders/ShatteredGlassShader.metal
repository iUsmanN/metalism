//
//  ShatteredGlassShader.metal
//  metalism
//
//  layerEffect: Voronoi-based shattered glass.
//  • Refraction + chromatic aberration at shard edges
//  • Radial blur inside each shard (frosted glass look), strongest at edges
//  • Extra blur right on the crack line itself
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── Hash helpers ──────────────────────────────────────────────────────────────

static float2 hash2(float2 p) {
    float2 q = float2(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)));
    return fract(sin(q) * 43758.5453);
}

// ── Voronoi ───────────────────────────────────────────────────────────────────
// Returns:
//   .x  dist to nearest cell centre
//   .y  dist to second-nearest cell centre
//   .zw absolute position of nearest cell site
static float4 voronoi(float2 uv, float cellScale) {
    float2 cell = floor(uv * cellScale);
    float2 frac = fract(uv * cellScale);

    float  minDist1 = 1e9;
    float  minDist2 = 1e9;
    float2 minSite  = float2(0.0);

    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            float2 neighbour = float2(float(i), float(j));
            float2 site      = hash2(cell + neighbour);
            float2 diff      = neighbour + site - frac;
            float  d         = length(diff);

            if (d < minDist1) {
                minDist2 = minDist1;
                minDist1 = d;
                minSite  = site + cell + neighbour;
            } else if (d < minDist2) {
                minDist2 = d;
            }
        }
    }

    return float4(minDist1, minDist2, minSite);
}

// ── Main shader ───────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 shatteredGlass(float2 position,
                     SwiftUI::Layer layer,
                     float2 size,
                     float  fragmentScale)   // 0.5 (large) … 10 (small)
{
    float2 uv  = position / size;

    float4 vor      = voronoi(uv, fragmentScale);
    float  d1       = vor.x;
    float  d2       = vor.y;
    float2 cellSite = vor.zw;

    // Edge proximity: 0 exactly at boundary, grows toward shard interior
    float edgeDist = d2 - d1;

    // Per-cell stable random direction for refraction
    float2 cellRand = hash2(cellSite) * 2.0 - 1.0;

    // Refraction: strongest at edge, zero in shard interior
    float edgeFactor = 1.0 - smoothstep(0.0, 0.18, edgeDist);
    float refrAmt    = edgeFactor * 28.0;
    float2 refrOffset = cellRand * refrAmt;

    // Chromatic aberration along refraction axis
    float  caAmt = edgeFactor * 10.0;
    float2 caDir = normalize(cellRand + float2(0.001));

    // ── Radial blur (frosted glass) ───────────────────────────────────────────
    // Blur spread: peaks near edge (edgeFactor), tapers off in shard interior.
    // Also add a constant base spread so even the interior looks slightly frosted.
    float maxSpread  = 7.0;                            // px at full edgeFactor
    float baseSpread = 1.5;                            // px ambient frost
    float blurSpread = edgeFactor * maxSpread + baseSpread;

    // 8 radial taps around the refracted base position
    float3 sumR = float3(0.0);
    float3 sumG = float3(0.0);
    float3 sumB = float3(0.0);
    int    taps = 8;
    float  wTotal = 0.0;

    for (int i = 0; i < taps; i++) {
        float angle = (float(i) / float(taps)) * 6.28318;
        float2 tapOffset = float2(cos(angle), sin(angle)) * blurSpread;

        float2 rPos = position + refrOffset + tapOffset + caDir * caAmt;
        float2 gPos = position + refrOffset + tapOffset;
        float2 bPos = position + refrOffset + tapOffset - caDir * caAmt;

        // Gaussian-ish weight: centre tap weighted more
        float w = 1.0;
        sumR += float3(layer.sample(rPos).r) * w;
        sumG += float3(layer.sample(gPos).g) * w;
        sumB += float3(layer.sample(bPos).b) * w;
        wTotal += w;
    }

    // Also include the exact centre sample at higher weight for sharpness
    float centreW = 3.0;
    float2 rCentre = position + refrOffset + caDir * caAmt;
    float2 gCentre = position + refrOffset;
    float2 bCentre = position + refrOffset - caDir * caAmt;
    sumR += float3(layer.sample(rCentre).r) * centreW;
    sumG += float3(layer.sample(gCentre).g) * centreW;
    sumB += float3(layer.sample(bCentre).b) * centreW;
    wTotal += centreW;

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    // ── Extra blur on the crack itself (diffusion through fractured edge) ──────
    // Very tight extra smear only within the crack seam
    float crackFactor = 1.0 - smoothstep(0.0, 0.025, edgeDist);
    float crackSpread = crackFactor * 5.0;

    if (crackFactor > 0.01) {
        float3 crackR = float3(0.0);
        float3 crackG = float3(0.0);
        float3 crackB = float3(0.0);
        float  crackW = 0.0;
        int    crackTaps = 6;
        for (int i = 0; i < crackTaps; i++) {
            float angle = (float(i) / float(crackTaps)) * 6.28318;
            float2 off = float2(cos(angle), sin(angle)) * crackSpread;
            crackR += float3(layer.sample(position + off + caDir * caAmt).r);
            crackG += float3(layer.sample(position + off).g);
            crackB += float3(layer.sample(position + off - caDir * caAmt).b);
            crackW += 1.0;
        }
        half cr = half(crackR.r / crackW);
        half cg = half(crackG.g / crackW);
        half cb = half(crackB.b / crackW);
        r = mix(r, cr, half(crackFactor));
        g = mix(g, cg, half(crackFactor));
        b = mix(b, cb, half(crackFactor));
    }

    // ── Dark seam at shard edges ──────────────────────────────────────────────
    float edgeLine = 1.0 - smoothstep(0.0, 0.015, edgeDist);
    float darken   = 1.0 - edgeLine * 0.55;
    r = half(float(r) * darken);
    g = half(float(g) * darken);
    b = half(float(b) * darken);

    return half4(r, g, b, 1.0h);
}
