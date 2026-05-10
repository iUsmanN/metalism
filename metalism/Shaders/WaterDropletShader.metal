//
//  WaterDropletShader.metal
//  metalism
//
//  layerEffect: Realistic water droplets on a surface.
//  • Irregular shape: base circle warped by angular noise (lumpy, not perfect)
//  • Slightly elongated vertically (squashed bead shape)
//  • Convex-lens refraction: content is magnified inside
//  • Chromatic aberration at the rim
//  • Darkened contact edge + small specular highlight
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── Utilities ─────────────────────────────────────────────────────────────────

static float wdl_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float2 wdl_hash2(float2 p) {
    float2 q = float2(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)));
    return fract(sin(q) * 43758.5453);
}

// Smooth value noise
static float wdl_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(wdl_hash(i),              wdl_hash(i + float2(1,0)), u.x),
               mix(wdl_hash(i + float2(0,1)), wdl_hash(i + float2(1,1)), u.x), u.y);
}

// ── Signed distance to one droplet ───────────────────────────────────────────
// Returns negative inside, 0 on edge, positive outside.
// `seed`  : unique per-droplet random float2
// `centre`: droplet centre in pixels
// `radius`: base radius in pixels
static float dropletSDF(float2 pos, float2 centre, float radius, float2 seed, float time) {
    float2 delta = pos - centre;

    // Slightly squash vertically (real sessile droplet is wider than tall)
    delta.y *= 1.25;

    float angle = atan2(delta.y, delta.x);
    float r     = length(delta);

    // Angular noise: 3 harmonics give a lumpy, organic edge
    float noise = 0.0;
    noise += 0.10 * sin(angle * 3.0 + seed.x * 6.28318 + time * 0.15);
    noise += 0.06 * sin(angle * 5.0 + seed.y * 6.28318 + time * 0.22);
    noise += 0.04 * sin(angle * 7.0 + (seed.x + seed.y) * 3.14159 + time * 0.18);

    float effectiveRadius = radius * (1.0 + noise);
    return r - effectiveRadius;
}

// ── Per-droplet hit info ──────────────────────────────────────────────────────

struct DropHit {
    bool   hit;
    float  sdf;       // signed distance (negative = inside)
    float2 normal;    // outward surface normal
    float2 centre;
    float  radius;
};

static DropHit findDroplet(float2 pos, float time) {
    float cellSize = 80.0;   // smaller → denser droplets

    float2 cell = floor(pos / cellSize);

    DropHit best;
    best.hit    = false;
    best.sdf    = 1e9;
    best.normal = float2(0, 1);
    best.centre = float2(0);
    best.radius = 0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 nb   = cell + float2(float(i), float(j));
            float2 seed = wdl_hash2(nb);

            // Place centre with more randomness, avoid strict grid look
            float2 centre = (nb + seed * 0.75 + 0.125) * cellSize;

            // Radius: 10–22 px (smaller than before)
            float radius = 10.0 + seed.x * 12.0;

            float sdf = dropletSDF(pos, centre, radius, seed, time);

            if (sdf < 0.0 && sdf < best.sdf) {
                best.hit    = true;
                best.sdf    = sdf;
                best.centre = centre;
                best.radius = radius;

                // Approximate normal: finite-difference gradient of the SDF
                float eps = 1.5;
                float dx = dropletSDF(pos + float2(eps, 0), centre, radius, seed, time)
                         - dropletSDF(pos - float2(eps, 0), centre, radius, seed, time);
                float dy = dropletSDF(pos + float2(0, eps), centre, radius, seed, time)
                         - dropletSDF(pos - float2(0, eps), centre, radius, seed, time);
                float2 grad = float2(dx, dy);
                best.normal = length(grad) > 0.001 ? normalize(grad) : float2(0, 1);
            }
        }
    }

    return best;
}

// ── Main ──────────────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 waterDroplet(float2 position,
                   SwiftUI::Layer layer,
                   float2 size,
                   float  time)
{
    DropHit hit = findDroplet(position, time);

    if (!hit.hit) {
        return layer.sample(position);
    }

    // Normalised depth inside droplet: 0 = edge, 1 = centre
    float depth = clamp(-hit.sdf / hit.radius, 0.0, 1.0);

    // ── Convex-lens refraction ────────────────────────────────────────────────
    // Inward pull: stronger at centre, zero at edge
    float refrStr = depth * depth * hit.radius * 0.5;
    float2 inward = -hit.normal;
    float2 samplePos = position + inward * refrStr;

    // ── Chromatic aberration at rim ───────────────────────────────────────────
    float rim   = 1.0 - smoothstep(0.0, 0.35, depth);   // strong near edge
    float caAmt = rim * 6.0;
    float2 caDir = hit.normal;

    half r = layer.sample(samplePos + caDir * caAmt).r;
    half g = layer.sample(samplePos).g;
    half b = layer.sample(samplePos - caDir * caAmt).b;

    // ── Rim blur (scatter at the contact edge) ────────────────────────────────
    // Blend the sharp sample with a radial average near the edge
    float blurSpread = rim * 5.0;
    if (blurSpread > 0.1) {
        float3 bR = float3(0), bG = float3(0), bB = float3(0);
        float  bW = 0.0;
        for (int k = 0; k < 6; k++) {
            float  angle = (float(k) / 6.0) * 6.28318;
            float2 off   = float2(cos(angle), sin(angle)) * blurSpread;
            bR += float3(layer.sample(samplePos + off + caDir * caAmt).r);
            bG += float3(layer.sample(samplePos + off).g);
            bB += float3(layer.sample(samplePos + off - caDir * caAmt).b);
            bW += 1.0;
        }
        half br = half(bR.r / bW);
        half bg = half(bG.g / bW);
        half bb = half(bB.b / bW);
        r = mix(r, br, half(rim));
        g = mix(g, bg, half(rim));
        b = mix(b, bb, half(rim));
    }

    // ── Subtle interior tint — very slight blue tint of water ─────────────────
    float tint = depth * depth * 0.06;
    b = min(b + half(tint), 1.0h);

    // ── Small specular highlight (top-left, like a light source) ─────────────
    // Fixed light dir; highlight is a tight Gaussian blob near top-left of droplet
    float2 lightOff = hit.centre + float2(-hit.radius * 0.3, -hit.radius * 0.35);
    float  hlDist   = length(position - lightOff) / (hit.radius * 0.22);
    float  specular = exp(-hlDist * hlDist) * 0.45 * depth;
    r = min(r + half(specular), 1.0h);
    g = min(g + half(specular), 1.0h);
    b = min(b + half(specular), 1.0h);

    return half4(r, g, b, 1.0h);
}
