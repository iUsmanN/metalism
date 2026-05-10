//
//  Wave3DShader.metal
//  metalism
//
//  colorEffect that renders a sine wave surface in 3-D perspective.
//  No blue — monochromatic white/grey palette with diffuse + specular lighting.
//  The wave flows toward the viewer along the Z axis.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Ray-march the wave surface in normalised 3-D space.
// Returns the surface height y at (worldX, worldZ).
static float waveHeight(float worldX, float worldZ, float time) {
    // Single sine across X, scrolling in Z (toward viewer)
    return 0.12 * sin(worldX * 2.8 - time * 1.6)
         + 0.06 * sin(worldX * 5.2 + worldZ * 1.1 - time * 2.1);
}

[[ stitchable ]]
half4 wave3D(float2 position,
             half4  currentColor,
             float2 size,
             float  time)
{
    // Normalised screen coords [-1, 1] with y flipped (y=1 at top)
    float2 uv = float2(
        (position.x / size.x) * 2.0 - 1.0,
        1.0 - (position.y / size.y) * 2.0
    );

    // ── Simple perspective camera ─────────────────────────────────────────────
    // Camera sits above-and-behind the surface looking at the origin.
    float3 camPos = float3(0.0, 1.2, 3.0);
    float3 target = float3(0.0, 0.0, 0.0);

    float3 forward = normalize(target - camPos);
    float3 right   = normalize(cross(float3(0, 1, 0), forward));
    float3 up      = cross(forward, right);

    // Ray direction through this pixel
    float fov = 0.7;   // roughly 70° FOV
    float3 rayDir = normalize(forward + uv.x * right * fov + uv.y * up * fov * (size.y / size.x));

    // ── Ray-march to find wave surface intersection ───────────────────────────
    // The wave lives on the XZ plane ± some height.
    // March along the ray; test y against waveHeight(x, z).
    float3 ro = camPos;
    float3 rd = rayDir;

    // If ray points upward and never hits the surface, return background.
    if (rd.y > -0.01) {
        float3 bg = float3(0.10, 0.10, 0.10);
        return half4(half3(bg), 1.0);
    }

    // Binary-search / step march
    float tMin = 0.1, tMax = 12.0;
    float t = tMin;
    float3 hitPos = float3(0.0);
    bool hit = false;

    for (int i = 0; i < 80; i++) {
        float3 p   = ro + rd * t;
        float  wh  = waveHeight(p.x, p.z, time);
        float  gap = p.y - wh;

        if (gap < 0.004) {
            hitPos = p;
            hit    = true;
            break;
        }
        // Adaptive step: closer to surface = finer steps
        t += max(gap * 0.5, 0.02);
        if (t > tMax) break;
    }

    if (!hit) {
        // Background — dark grey gradient (horizon lighter)
        float horizonT = saturate(1.0 + uv.y * 4.0);
        float3 bg = mix(float3(0.06, 0.06, 0.06), float3(0.22, 0.22, 0.22), horizonT);
        return half4(half3(bg), 1.0);
    }

    // ── Surface normal via finite differences ─────────────────────────────────
    float eps = 0.02;
    float dX = waveHeight(hitPos.x + eps, hitPos.z, time)
             - waveHeight(hitPos.x - eps, hitPos.z, time);
    float dZ = waveHeight(hitPos.x, hitPos.z + eps, time)
             - waveHeight(hitPos.x, hitPos.z - eps, time);
    float3 normal = normalize(float3(-dX, 2.0 * eps, -dZ));

    // ── Lighting (single directional light, no colour) ────────────────────────
    float3 lightDir = normalize(float3(0.4, 1.0, 0.5));
    float3 viewDir  = normalize(camPos - hitPos);
    float3 halfDir  = normalize(lightDir + viewDir);

    float diffuse  = max(dot(normal, lightDir), 0.0);
    float specular = pow(max(dot(normal, halfDir), 0.0), 48.0);

    // Base surface colour — neutral mid-grey
    float3 baseCol  = float3(0.55, 0.55, 0.55);
    float3 ambient  = float3(0.08, 0.08, 0.08);
    float3 surfCol  = ambient + baseCol * diffuse * 0.9 + float3(1.0) * specular * 0.6;

    // Depth fog — fade to dark grey in the distance
    float fogT  = saturate((t - 2.0) / 8.0);
    float3 fog  = float3(0.10, 0.10, 0.10);
    float3 col  = mix(surfCol, fog, fogT * fogT);

    return half4(half3(saturate(col)), 1.0);
}
