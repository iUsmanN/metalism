//
//  RedCloudShader.metal
//  metalism
//
//  Full-screen grid of "0" and "1" characters. Cloud-shaped regions built from
//  smooth metaball-style blobs driven by noise give a natural cloud silhouette.
//  Blobs drift downward over time. White letters, black background.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ── Hash / noise ──────────────────────────────────────────────────────────────

static float hash21(float2 p) {
    p = fract(p * float2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

static float hash11(float n) {
    return fract(sin(n) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + float2(1,0)), u.x),
               mix(hash21(i + float2(0,1)), hash21(i + float2(1,1)), u.x), u.y);
}

// ── Metaball cloud field ──────────────────────────────────────────────────────
// Sums smooth radial falloff from a set of blob centres that are placed on a
// loose grid and jittered by noise. This produces rounded, bumpy cloud shapes.

static float cloudField(float2 p, float time) {
    float field = 0.0;

    float cellW = 0.50, cellH = 0.42;

    for (int col = -1; col <= 4; col++) {
        for (int row = -2; row <= 6; row++) {
            float id = float(col * 11 + row);

            // Jitter within cell
            float jx = (hash11(id * 3.1) - 0.5) * cellW * 0.7;
            float jy = (hash11(id * 4.7) - 0.5) * cellH * 0.5;

            // Continuous downward drift — no fract, just mod over a large tile
            float speed  = 0.05 + hash11(id * 1.3) * 0.04;
            float wobble = sin(time * 0.35 + hash11(id * 2.7) * 6.28) * 0.05;

            float baseX = float(col) * cellW + jx + wobble;
            // Drift Y downward and wrap smoothly over cellH * numRows range
            float tileH  = cellH * 8.0;   // total tile height
            float baseY  = float(row) * cellH + jy;
            float driftY = time * speed;
            // Use mod so the blob reappears at the top after leaving the bottom
            float centreY = baseY + driftY;
            // Keep centreY in a window around p.y for the wrap to work:
            // shift by multiples of tileH so the blob is always in view range
            centreY = centreY - tileH * floor((centreY - p.y + tileH * 0.5) / tileH);

            float2 centre = float2(baseX, centreY);

            float radius = 0.13 + hash11(id * 6.3) * 0.09;
            float d = length(p - centre);
            float c = max(0.0, 1.0 - (d / radius) * (d / radius));
            field += c * c;
        }
    }
    return field;
}

// ── SDF characters ────────────────────────────────────────────────────────────

static float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    return length(pa - ba * saturate(dot(pa, ba) / dot(ba, ba)));
}

static float sdZero(float2 uv) {
    float2 q = abs(uv) - float2(0.22, 0.34) + 0.10;
    float outer = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.10;
    float2 qi = abs(uv) - float2(0.10, 0.22) + 0.08;
    float inner = length(max(qi, 0.0)) + min(max(qi.x, qi.y), 0.0) - 0.08;
    return max(outer, -inner);
}

static float sdOne(float2 uv) {
    float stem = sdSegment(uv, float2(0.0, -0.36), float2(0.0, 0.36)) - 0.055;
    float flag = sdSegment(uv, float2(-0.10, 0.36), float2(0.0, 0.20)) - 0.045;
    return min(stem, flag);
}

// ── Main shader ───────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 redCloud(float2 position,
               half4  color,
               float2 size,
               float  time)
{
    float2 uv = position / size.y;   // aspect-corrected, y in [0..1]

    // Cloud field threshold — tune for density
    float field   = cloudField(uv, time);
    bool  inCloud = field > 0.55;

    // ── Character grid ────────────────────────────────────────────────────────
    float cellSize   = 14.0;
    float2 cellIdx   = floor(position / cellSize);
    float2 cellCentre = (cellIdx + 0.5) * cellSize;
    float2 cuv       = (position - cellCentre) / (cellSize * 0.5);  // -1..1

    float d      = inCloud ? sdZero(cuv * 0.85) : sdOne(cuv * 0.85);
    float aa     = fwidth(d);
    float filled = 1.0 - smoothstep(-aa, aa, d);

    return half4(half3(float3(filled)), 1.0h);
}
