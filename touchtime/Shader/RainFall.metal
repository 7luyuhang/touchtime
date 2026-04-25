//
//  RainFall.metal
//  touchtime
//
//  Adapted from a public-domain rain shader by Кизим Илья.
//  Reworked as a SwiftUI layerEffect that distorts the underlying view
//  with a rainy-glass effect of configurable intensity.
//

#include <SwiftUI/SwiftUI_Metal.h>
#include <metal_stdlib>
using namespace metal;

#define S(a, b, t) smoothstep(a, b, t)

namespace rain {

float3 N13(float p) {
    float3 p3 = fract(float3(p) * float3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(float3((p3.x + p3.y) * p3.z,
                        (p3.x + p3.z) * p3.y,
                        (p3.y + p3.z) * p3.x));
}

float N(float t) {
    return fract(sin(t * 12345.564) * 7658.76);
}

float Saw(float b, float t) {
    return S(0., b, t) * S(1., b, t);
}

float2 DropLayer2(float2 uv, float t) {
    float2 UV = uv;
    uv.y += t * 0.75;
    // Original aspect - keeps drop and trail extents inside their cells
    // so we don't get visible horizontal/vertical "cut" artifacts.
    float2 a = float2(6., 1.);
    float2 grid = a * 2.;
    float2 id = floor(uv * grid);
    float colShift = N(id.x);
    uv.y += colShift;
    id = floor(uv * grid);
    float3 n = N13(id.x * 35.2 + id.y * 2376.1);
    float2 st = fract(uv * grid) - float2(.5, 0);
    float x = n.x - .5;
    float y = UV.y * 20.;
    float wiggle = sin(y + sin(y));
    x += wiggle * (.5 - abs(x)) * (n.z - .5);
    x *= .7;
    float ti = fract(t + n.z);
    y = (Saw(.85, ti) - .5) * .9 + .5;
    float2 p = float2(x, y);
    float d = length((st - p) * a.yx);
    // Skip ~50% of cells so the falling drops are sparser.
    float keep = step(0.5, fract(n.z * 13.7 + n.x * 9.13));
    float mainDrop = S(.4, .0, d) * keep;
    float r = sqrt(S(1., y, st.y));
    float cd = abs(st.x - x);
    float trail = S(.23 * r, .15 * r * r, cd);
    float trailFront = S(-.02, .02, st.y - y);
    trail *= trailFront * r * r;
    y = UV.y;
    float trail2 = S(.2 * r, .0, cd);
    float droplets = max(0., (sin(y * (1. - y) * 120.) - st.y)) * trail2 * trailFront * n.z;
    y = fract(y * 10.) + (st.y - .5);
    float dd = length(st - float2(x, y));
    droplets = S(.3, 0., dd);
    float m = mainDrop + droplets * r * trailFront * keep;
    return float2(m, trail * keep);
}

float StaticDrops(float2 uv, float t) {
    uv *= 40.;
    float2 id = floor(uv);
    uv = fract(uv) - .5;
    float3 n = N13(id.x * 107.45 + id.y * 3543.654);
    // Tightened from .7 to .4 so a drop never extends past its cell, which
    // would otherwise show up as a hard line where the next cell begins.
    float2 p = (n.xy - .5) * .4;
    float d = length(uv - p);
    float fade = Saw(.025, fract(t + n.z));
    // Skip ~65% of cells based on a per-cell random so the static drops are
    // sparse instead of completely covering every cell.
    float keep = step(0.65, fract(n.z * 17.3 + n.x * 5.71));
    float c = S(.3, 0., d) * fract(n.z * 10.) * fade * keep;
    return c;
}

float2 Drops(float2 uv, float t, float l0, float l1, float l2) {
    float s = StaticDrops(uv, t) * l0;
    float2 m1 = DropLayer2(uv, t) * l1;
    float2 m2 = DropLayer2(uv * 1.85, t) * l2;
    float c = s + m1.x + m2.x;
    c = S(.3, 1., c);
    return float2(c, max(m1.y * l0, m2.y * l1));
}

} // namespace rain

// `size` is the view size in points so we can build a stable centered uv
// regardless of the bounding rect. `iTime` is seconds since the effect
// started. `intensity` is in [0, 1] and controls how much rain is drawn.
[[ stitchable ]]
half4 rainFall(float2 pos,
               SwiftUI::Layer layer,
               float2 size,
               float iTime,
               float intensity)
{
    float w = max(size.x, 1.0);
    float h = max(size.y, 1.0);

    // Centered uv normalized by height (matches the original shader's layout).
    float2 uv;
    uv.x = (pos.x - 0.5 * w) / h;
    uv.y = (pos.y - 0.5 * h) / h;
    uv.y = -uv.y;

    // Time scale - tuned so drops look natural at typical row sizes.
    float t = iTime * 0.05;

    float rainAmount = clamp(intensity, 0.0, 1.0);

    // Lower factor zooms in further; 0.7 makes drops ~2.1x larger than the
    // shader's original 1.5 setting while keeping cells/drops in proportion.
    uv *= 0.50;

    // Tightened curves so even moderate rainAmount stays visually sparse.
    float staticDrops = S(.1, 1., rainAmount);
    float layer1 = S(.4, 1., rainAmount);
    float layer2 = S(.2, .8, rainAmount);

    float2 c = rain::Drops(uv, t, staticDrops, layer1, layer2);
    float2 e = float2(.001, 0.);
    float cx = rain::Drops(uv + e, t, staticDrops, layer1, layer2).x;
    float cy = rain::Drops(uv + e.yx, t, staticDrops, layer1, layer2).x;
    float2 nrm = float2(cx - c.x, cy - c.x);

    // ---- Lens-style refraction ----
    // A real droplet on glass behaves like a tiny convex lens: it inverts and
    // magnifies the background. We push the sample along the gradient
    // (refraction at the surface) and add a small inverted term inside the
    // body so what's "under" the drop reads as flipped/zoomed, not just
    // shifted.
    float bodyMask = clamp(c.x, 0.0, 1.0);
    float2 refract = nrm * h * 1.4;
    float2 lensFlip = -nrm * h * 6.0 * bodyMask;
    float2 pixelOffset = clamp(refract + lensFlip, -40.0, 40.0);

    // Safety clamp: keep the sample inside the layer bounds so a drop near
    // the edge can never sample transparent pixels (which would show up as a
    // black refractive halo on the rounded corners).
    float2 sampleP = clamp(pos + pixelOffset, float2(0.5), size - float2(0.5));
    half4 col = layer.sample(sampleP);

    // Subtle chromatic aberration along the silhouette - real water lenses
    // disperse light, so R and B fringes split slightly at the drop edge.
    half edgeMag = clamp(half(length(nrm)) * 25.0h, 0.0h, 1.0h);
    if (edgeMag > 0.02h) {
        float2 caOffset = nrm * h * 0.6;
        float2 spR = clamp(pos + pixelOffset + caOffset, float2(0.5), size - float2(0.5));
        float2 spB = clamp(pos + pixelOffset - caOffset, float2(0.5), size - float2(0.5));
        half rCh = layer.sample(spR).r;
        half bCh = layer.sample(spB).b;
        col.r = mix(col.r, rCh, edgeMag * 0.5h);
        col.b = mix(col.b, bCh, edgeMag * 0.5h);
    }

    // ---- Realistic drop shading ----
    half cx_h = clamp(half(c.x), 0.0h, 1.0h);
    half cy_h = clamp(half(c.y), 0.0h, 1.0h);

    // Approximate hemispherical surface normal of the drop from the gradient.
    half2 nh = half2(nrm) * 200.0h;
    half nLen2 = clamp(dot(nh, nh), 0.0h, 1.0h);
    half3 N = normalize(half3(nh, sqrt(max(1.0h - nLen2, 0.0001h))));

    // Light from upper-left (the eye expects this from photographs).
    const half3 L  = normalize(half3(-0.45h,  0.55h, 0.70h));
    const half3 V  = half3(0.0h, 0.0h, 1.0h);
    const half3 H  = normalize(L + V);

    half NdotL = max(dot(N, L), 0.0h);
    half NdotH = max(dot(N, H), 0.0h);
    half NdotV = max(dot(N, V), 0.0h);

    // 1. Body brightening so the drop reads as clear water, not just a smear.
    half body = cx_h * 0.08h;

    // 2. Directional specular - sharp pinpoint biased to the upper-left,
    //    softened by a wider halo.
    half specSharp = pow(NdotH, 64.0h) * cx_h * 0.55h;
    half specSoft  = pow(NdotH,  6.0h) * cx_h * 0.12h;
    half3 highlightTint = mix(col.rgb, half3(1.0h), 0.55h);

    // 3. Caustic / focused light at the side opposite the highlight - the
    //    lens concentrates light there, giving the drop its luminous bottom.
    half causticMask = pow(max(-dot(N, L), 0.0h), 3.0h) * cx_h;
    half caustic = causticMask * 0.18h;

    // 4. Fresnel rim: brighter on the silhouette where viewing is grazing.
    half fres = pow(1.0h - NdotV, 3.0h) * cx_h;
    half rimLight = fres * 0.20h;

    // 5. Soft contact shadow opposite the highlight - sells the bump.
    half shadow = (1.0h - NdotL) * cx_h * 0.10h;

    // 6. Wet-streak darkening along trails, like water film on glass.
    half trailDark = cy_h * 0.06h;

    col.rgb = clamp(col.rgb
                        + body            * col.a
                        + specSharp       * highlightTint * col.a
                        + specSoft        * highlightTint * col.a
                        + caustic         * highlightTint * col.a
                        + rimLight        * highlightTint * col.a
                        - shadow          * col.a
                        - trailDark       * col.a,
                    0.0h, 1.0h);

    return col;
}
