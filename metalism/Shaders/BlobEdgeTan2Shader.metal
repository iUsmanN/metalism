//
//  BlobEdgeTan2Shader.metal
//  metalism
//
//  Simulates looking down at a circular glass ring from above.
//  The ring occupies 55%–105% of circleRadius. A cosine thickness profile
//  makes the glass thickest at both edges and thinnest at the midpoint (80%).
//  Refraction, chromatic aberration, caustic glow and specular all follow
//  the physical behaviour of a curved glass surface seen from the top.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 blobEdgeTan2(float2 position,
                   SwiftUI::Layer layer,
                   float2 centre,
                   float  radius,
                   float  ringWidth,
                   float  scrollOffset,
                   float  blurRadius,
                   float  refractionStr,   // refraction strength multiplier (default 1.0)
                   float  specularStr,     // specular intensity multiplier (default 1.0)
                   float  causticStr)      // caustic rim glow multiplier (default 1.0)
{
    float2 delta = position - centre;
    float  dist  = length(delta);

    // Outside the outer edge — untouched
    if (dist > radius) {
        return layer.sample(position);
    }

    float innerBoundary = radius - ringWidth;

    // Inside the inner edge — untouched
    if (dist < innerBoundary) {
        return layer.sample(position);
    }

    // u ∈ [0,1]: 0 = inner edge, 1 = outer edge
    float u = (dist - innerBoundary) / ringWidth;

    // Cosine thickness profile — 1 at both edges, 0 at midpoint (u=0.5)
    // Represents the cross-sectional thickness of a torus viewed from above.
    float thickness = (cos(u * 6.28318) + 1.0) * 0.5;

    // Surface normal of the curved glass in the radial plane.
    // At u<0.5 (inner half): the surface curves away → normal tilts outward (+radial).
    // At u>0.5 (outer half): the surface curves toward viewer → normal tilts inward (-radial).
    // sin(u*2π) goes +→0→- crossing zero at the midpoint, giving us that sign flip.
    float normalTilt  = sin(u * 6.28318);   // +1 at inner edge, -1 at outer edge
    float2 radial     = dist > 0.001 ? normalize(delta) : float2(1.0, 0.0);
    float2 tangent    = float2(-radial.y, radial.x);

    // ── Refraction ────────────────────────────────────────────────────────────
    // Glass with higher IOR bends rays toward the surface normal.
    // normalTilt > 0 (inner half) → pull sample inward (toward centre).
    // normalTilt < 0 (outer half) → pull sample outward (away from centre).
    // This makes the ring appear to magnify/bend content through its curved walls.
    float refrStr    = 48.0 * refractionStr;
    float2 refrOff   = radial * (normalTilt * refrStr);

    // Additional thickness-driven compression: thicker glass displaces more.
    float thickRefrStr = 20.0 * refractionStr;
    float2 thickOff    = -radial * thickness * thickRefrStr;

    float2 sampleBase  = position + refrOff + thickOff;

    // ── Chromatic aberration — split R/B along radial axis ────────────────────
    // Real glass disperses wavelengths; thicker = more split.
    float caAmt = thickness * 10.0;

    // ── Blur proportional to thickness (frosted/curved glass blurs more) ──────
    float sigma = max(blurRadius * thickness * 0.5, 0.5);
    float bStep = sigma * 0.6;

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wT   = 0.0;

    float w0 = 1.0;
    sumR   += float3(layer.sample(sampleBase + radial * caAmt).r) * w0;
    sumG   += float3(layer.sample(sampleBase).g)                  * w0;
    sumB   += float3(layer.sample(sampleBase - radial * caAmt).b) * w0;
    wT     += w0;

    for (int k = 1; k <= 6; k++) {
        float t  = float(k);
        float wk = exp(-(t * t) / (2.0 * sigma * sigma / (bStep * bStep)));
        float o  = t * bStep;
        float2 px = float2(o, 0.0);
        float2 py = float2(0.0, o);

        sumR += float3(layer.sample(sampleBase + px + radial * caAmt).r
                     + layer.sample(sampleBase - px + radial * caAmt).r) * wk;
        sumG += float3(layer.sample(sampleBase + px).g
                     + layer.sample(sampleBase - px).g) * wk;
        sumB += float3(layer.sample(sampleBase + px - radial * caAmt).b
                     + layer.sample(sampleBase - px - radial * caAmt).b) * wk;

        sumR += float3(layer.sample(sampleBase + py + radial * caAmt).r
                     + layer.sample(sampleBase - py + radial * caAmt).r) * wk;
        sumG += float3(layer.sample(sampleBase + py).g
                     + layer.sample(sampleBase - py).g) * wk;
        sumB += float3(layer.sample(sampleBase + py - radial * caAmt).b
                     + layer.sample(sampleBase - py - radial * caAmt).b) * wk;

        wT += wk * 4.0;
    }

    float3 refracted = float3(sumR.r / wT, sumG.g / wT, sumB.b / wT);

    // ── Fresnel-style specular ────────────────────────────────────────────────
    // Specular peaks at both edges (high thickness) — like grazing-angle Fresnel.
    // Light direction rotates with scroll so the highlight tracks content movement.
    float scrollAngle = scrollOffset * 0.008;
    float cosS = cos(scrollAngle), sinS = sin(scrollAngle);

    float2 baseLight1 = normalize(float2( 0.6, -0.8));
    float2 baseLight2 = normalize(float2(-0.5,  0.7));
    float2 light1 = float2(cosS * baseLight1.x - sinS * baseLight1.y,
                           sinS * baseLight1.x + cosS * baseLight1.y);
    float2 light2 = float2(cosS * baseLight2.x - sinS * baseLight2.y,
                           sinS * baseLight2.x + cosS * baseLight2.y);

    // Sharp key + broad fill, both scaled by thickness (Fresnel peaks at edges)
    float spec1 = pow(saturate(dot(radial, light1)), 28.0) * thickness;
    float spec2 = pow(saturate(dot(radial, light2)),  8.0) * thickness;

    float3 specColor = spec1 * float3(1.0,  0.97, 0.90) * 0.55 * specularStr
                     + spec2 * float3(0.80, 0.90, 1.0)  * 0.25 * specularStr;

    // ── Caustic rim glow at both edges ────────────────────────────────────────
    // Real glass focuses light at its edges — a bright rim caustic.
    float edgeGlow   = pow(thickness, 3.0) * 0.18 * causticStr;
    float3 caustic   = float3(edgeGlow * 1.0, edgeGlow * 0.98, edgeGlow * 0.92);

    // ── Tint: glass darkens slightly at thicker regions ──────────────────────
    float3 tinted    = refracted * (1.0 - thickness * 0.15);

    float3 finalColor = saturate(tinted + specColor + caustic);

    // Smooth fade at inner and outer boundaries (4pt feather)
    float innerFade = smoothstep(innerBoundary, innerBoundary + 4.0, dist);
    float outerFade = smoothstep(radius, radius - 4.0, dist);
    float ringMask  = innerFade * outerFade;

    half4 original = layer.sample(position);
    float3 blended  = mix(float3(original.rgb), finalColor, ringMask);

    return half4(half3(blended), 1.0h);
}
