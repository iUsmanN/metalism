//
//  RadialShatterShader.metal
//  metalism
//
//  layerEffect: Radial shattered glass effect centred on a tap point.
//  • Diamond-shaped fragments oriented with a point toward the impact
//  • Fragment size grows with distance from the impact (tiny at centre, large far out)
//  • Refraction + chromatic aberration at shard edges
//  • Frosted radial blur, stronger near edges
//  • Expanding wave front reveals the effect outward from the tap
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── Hash ──────────────────────────────────────────────────────────────────────

static float2 rsg_hash2(float2 p) {
    float2 q = float2(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)));
    return fract(sin(q) * 43758.5453);
}

// ── Diamond-oriented Voronoi ──────────────────────────────────────────────────
// The local cell space is rotated so the radial axis points toward the impact.
// Distances use L1 (Manhattan / diamond) metric in that rotated frame, which
// produces diamond-shaped cells whose pointed ends face the impact centre.
//
// uv         : normalised screen position
// impactUV   : impact point in UV
// cellScale  : cells per unit — higher → smaller fragments
static float4 rsg_diamondVoronoi(float2 uv, float2 impactUV, float cellScale) {

    // Radial direction from impact to this pixel (aspect-corrected in UV space)
    float2 toPixel = uv - impactUV;
    float  len     = length(toPixel);

    // Build a rotation matrix that aligns +X with the radial direction
    float2 radial = len > 0.001 ? (toPixel / len) : float2(1.0, 0.0);
    float2 tangent = float2(-radial.y, radial.x);

    // Project UV into the rotated frame
    float2 rotUV = float2(dot(uv, radial), dot(uv, tangent)) * cellScale;

    float2 cell = floor(rotUV);
    float2 frac = fract(rotUV);

    float  minDist1 = 1e9;
    float  minDist2 = 1e9;
    float2 minSite  = float2(0.0);

    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            float2 nb   = float2(float(i), float(j));
            float2 site = rsg_hash2(cell + nb);   // random offset within cell
            float2 diff = nb + site - frac;

            // L1 (Manhattan) distance → diamond-shaped cells
            float d = abs(diff.x) + abs(diff.y);

            if (d < minDist1) {
                minDist2 = minDist1;
                minDist1 = d;
                minSite  = site + cell + nb;
            } else if (d < minDist2) {
                minDist2 = d;
            }
        }
    }

    return float4(minDist1, minDist2, minSite);
}

// ── Main shader ───────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 radialShatter(float2 position,
                    SwiftUI::Layer layer,
                    float2 size,
                    float2 impactPoint,   // tap location in points
                    float  strength,      // 0 = no effect, 1 = full effect
                    float  waveRadius)    // expanding radius in UV units
{
    if (strength < 0.001) {
        return layer.sample(position);
    }

    float2 uv       = position / size;
    float2 impactUV = impactPoint / size;

    // Aspect-corrected distance from impact
    float aspect = size.x / size.y;
    float2 delta = (uv - impactUV) * float2(aspect, 1.0);
    float  dist  = length(delta);

    // Gate to expanding wave front.
    // Trailing ramp width 0.25 ensures no gaps at screen corners during travel.
    // When waveRadius is huge (effect locked in) the smoothstep fully saturates.
    float trailWidth = 0.25;
    float pixelStrength = strength * smoothstep(waveRadius, waveRadius - trailWidth, dist)
                                   * smoothstep(0.0, 0.06, waveRadius - dist + 0.06);
    if (pixelStrength < 0.001) {
        return layer.sample(position);
    }

    // Fragment scale: tiny at impact, growing with distance
    float minScale = 5.0;
    float maxScale = 22.0;
    float cellScale = mix(maxScale, minScale, smoothstep(0.0, 0.8, dist));

    float4 vor      = rsg_diamondVoronoi(uv, impactUV, cellScale);
    float  d1       = vor.x;
    float  d2       = vor.y;
    float2 cellSite = vor.zw;

    // Edge proximity in L1 space
    float edgeDist = d2 - d1;

    // Per-cell stable random direction
    float2 cellRand   = rsg_hash2(cellSite) * 2.0 - 1.0;
    float  edgeFactor = 1.0 - smoothstep(0.0, 0.18, edgeDist);
    float  distFalloff = 1.0 - smoothstep(0.0, 0.85, dist);

    float  refrAmt    = edgeFactor * 28.0 * pixelStrength * (0.3 + 0.7 * distFalloff);
    float2 refrOffset = cellRand * refrAmt;

    float  caAmt = edgeFactor * 10.0 * pixelStrength * (0.3 + 0.7 * distFalloff);
    float2 caDir = normalize(cellRand + float2(0.001));

    // ── Frosted blur ──────────────────────────────────────────────────────────
    float blurSpread = edgeFactor * 7.0 * pixelStrength + 1.2 * pixelStrength;

    float3 sumR = float3(0.0), sumG = float3(0.0), sumB = float3(0.0);
    float  wTotal = 0.0;

    for (int i = 0; i < 8; i++) {
        float  angle = (float(i) / 8.0) * 6.28318;
        float2 off   = float2(cos(angle), sin(angle)) * blurSpread;
        sumR += float3(layer.sample(position + refrOffset + off + caDir * caAmt).r);
        sumG += float3(layer.sample(position + refrOffset + off).g);
        sumB += float3(layer.sample(position + refrOffset + off - caDir * caAmt).b);
        wTotal += 1.0;
    }
    sumR += float3(layer.sample(position + refrOffset + caDir * caAmt).r) * 3.0;
    sumG += float3(layer.sample(position + refrOffset).g)                 * 3.0;
    sumB += float3(layer.sample(position + refrOffset - caDir * caAmt).b) * 3.0;
    wTotal += 3.0;

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    // ── Crack-line blur ───────────────────────────────────────────────────────
    float crackFactor = (1.0 - smoothstep(0.0, 0.025, edgeDist)) * pixelStrength;
    if (crackFactor > 0.01) {
        float  cSpread = crackFactor * 5.0;
        float3 cR = float3(0.0), cG = float3(0.0), cB = float3(0.0);
        float  cW = 0.0;
        for (int i = 0; i < 6; i++) {
            float  angle = (float(i) / 6.0) * 6.28318;
            float2 off   = float2(cos(angle), sin(angle)) * cSpread;
            cR += float3(layer.sample(position + off + caDir * caAmt).r);
            cG += float3(layer.sample(position + off).g);
            cB += float3(layer.sample(position + off - caDir * caAmt).b);
            cW += 1.0;
        }
        r = mix(r, half(cR.r / cW), half(crackFactor));
        g = mix(g, half(cG.g / cW), half(crackFactor));
        b = mix(b, half(cB.b / cW), half(crackFactor));
    }

    // ── Dark crack line ───────────────────────────────────────────────────────
    float edgeLine = 1.0 - smoothstep(0.0, 0.015, edgeDist);
    float darken   = 1.0 - edgeLine * 0.55 * pixelStrength;
    r = half(float(r) * darken);
    g = half(float(g) * darken);
    b = half(float(b) * darken);

    // Blend with unshattered original
    half4 original = layer.sample(position);
    r = mix(original.r, r, half(pixelStrength));
    g = mix(original.g, g, half(pixelStrength));
    b = mix(original.b, b, half(pixelStrength));

    return half4(r, g, b, 1.0h);
}
