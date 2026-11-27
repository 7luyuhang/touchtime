//
//  CloudDrift.metal
//  touchtime
//
//  Cumulus drifting across a cloudy sky: two layers of clouds grown from
//  noise, bright where the light reaches them and shaded where it has more
//  cloud to cross. Used as a SwiftUI colorEffect on a full-bleed overlay
//  above the sky.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

namespace clouds {

// How far the masses' noise is spread around 0.5, set so that the share of
// the view under cloud comes out close to the `cover` asked for.
constant float massGain = 1.5;
// How far the field rises past the threshold from a cloud's edge to its body.
constant float edgeSoftness = 0.12;
// How much the billows add to, or take from, the masses, and the most they
// can add.
constant float billowAmount = 0.16;
constant float billowReach = 0.1;
// How far the field rises past the threshold from lit to fully shaded.
constant float shadeSoftness = 0.3;
// What the threshold rises to where the clouds thin out, by the time they're
// gone. The more of the sky they cover, the more of them breaks up on the
// way, rather than fading as one sheet; scattered clouds mostly just fade.
constant float thinnedThreshold = 0.65;
// How many times as soft the clouds' edges are by then, fraying into wisps
// rather than staying as crisp as the clouds above.
constant float thinnedSoftening = 5.0;

// A hash on whole numbers, so a lattice point gets the same value whichever
// cell asks for it, however far the clouds have drifted.
static uint hash(int2 cell) {
    uint h = uint(cell.x) * 0x27d4eb2du + uint(cell.y) * 0x165667b1u;
    h ^= h >> 15;
    h *= 0x2c1b3c6du;
    h ^= h >> 12;
    h *= 0x297a2d39u;
    h ^= h >> 15;
    return h;
}

static float latticeValue(int2 cell) {
    return float(hash(cell) >> 8) * (1.0 / 16777216.0);
}

static float2 latticeGradient(int2 cell) {
    uint h = hash(cell);
    return float2(float(h & 0xffffu), float(h >> 16)) * (2.0 / 65535.0) - 1.0;
}

// Value noise in 0...1.
static float valueNoise(float2 p) {
    float2 corner = floor(p);
    int2 cell = int2(corner);
    float2 f = p - corner;
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = latticeValue(cell);
    float b = latticeValue(cell + int2(1, 0));
    float c = latticeValue(cell + int2(0, 1));
    float d = latticeValue(cell + int2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Gradient noise in about -0.5...0.5. Rounder than value noise and less
// tied to its lattice, so it gives the clouds their shapes.
static float gradientNoise(float2 p) {
    float2 corner = floor(p);
    int2 cell = int2(corner);
    float2 f = p - corner;
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = dot(latticeGradient(cell), f);
    float b = dot(latticeGradient(cell + int2(1, 0)), f - float2(1.0, 0.0));
    float c = dot(latticeGradient(cell + int2(0, 1)), f - float2(0.0, 1.0));
    float d = dot(latticeGradient(cell + int2(1, 1)), f - float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// The next octave: twice as fine, turned, and sliding a little against the
// one before, so the clouds slowly change shape as they drift.
static float2 nextOctave(float2 p, float t) {
    return float2x2(1.6, 1.2, -1.2, 1.6) * p + float2(0.09, -0.03) * t;
}

// A noise value folded around its middle: round lobes with soft creases
// between them.
static float lobes(float n) {
    float v = 2.0 * n - 1.0;
    return sqrt(v * v + 0.03);
}

struct Layer {
    float coverage; // 0 for clear sky, 1 for cloud
    float light;    // 0 in shade, 1 in full light
};

// One layer of clouds at `p`, where the field has to reach `threshold` to
// count as cloud, and further where they thin out, `thinning` of the way to
// gone. A near layer looks toward the light, `toLight` away in the layer's
// own space, for cloud standing in the way; a far one has fewer billows and
// no such look.
static Layer layer(float2 p, float t, float threshold, float thinning, float2 toLight, bool isNear) {
    Layer result;
    result.coverage = 0.0;
    result.light = 0.0;

    // Only what counts as cloud thins out. The shading still goes by
    // `threshold`, as it would in the full clouds, so that what's left of
    // them doesn't light up along its edges.
    float cutoff = mix(threshold, max(threshold, thinnedThreshold), thinning);
    float softness = edgeSoftness * mix(1.0, thinnedSoftening, thinning);

    // The masses of the clouds: three octaves, bunched around 0.5
    float masses = 0.55 * gradientNoise(p);
    float2 q = nextOctave(p, t);
    masses += 0.28 * gradientNoise(q);
    // The two coarsest octaves on their own, around 0.5 as well
    float broadMasses = 0.5 + masses * (massGain / 0.83);
    q = nextOctave(q, t);
    masses = 0.5 + (masses + 0.17 * gradientNoise(q)) * massGain;

    // Clear sky, further from a cloud than any billow reaches
    if (masses < cutoff - billowReach) {
        return result;
    }

    // Billows: finer octaves folded into lobes, which puff up the clouds'
    // edges and crease their faces
    q = nextOctave(q, t);
    float billows = 0.5 * lobes(valueNoise(q));
    q = nextOctave(q, t);
    billows += 0.3 * lobes(valueNoise(q));
    if (isNear) {
        q = nextOctave(q, t);
        billows += 0.2 * lobes(valueNoise(q));
    } else {
        billows *= 1.25;
    }
    float detail = billows - 0.4;

    result.coverage = smoothstep(0.0, softness, masses + detail * billowAmount - cutoff);
    if (result.coverage <= 0.0) {
        return result;
    }

    // How much cloud the light crosses on its way here
    float depth;
    if (isNear) {
        float2 s = p + toLight;
        float toward = 0.55 * gradientNoise(s);
        toward += 0.28 * gradientNoise(nextOctave(s, t));
        toward = 0.5 + toward * (massGain / 0.83);
        depth = clamp((toward - threshold) / shadeSoftness, 0.0, 1.0);
    } else {
        // How deep the point itself sits in its cloud stands in for that
        depth = 0.7 * clamp((broadMasses - threshold) / shadeSoftness, 0.0, 1.0);
    }
    // Lobes catch the light and the creases between them lose it
    result.light = clamp(exp(-2.2 * depth) + 0.35 * detail, 0.0, 1.0);
    return result;
}

} // namespace clouds

// `size`     view size in points.
// `unit`     how big the clouds are, in points; they grow and shrink with it.
// `time`     seconds, for the drift; the clouds also change shape with it.
// `cover`    how much of the sky is under cloud, in [0, 1]. Close to 0 the
//            clouds thin out to nothing.
// `seed`     in [0, 1); skies with different seeds get different clouds.
// `lit`      a cloud where the light falls on it, and
// `shade`    where it doesn't, both premultiplied by the opacity of the sky
//            they drift across.
// `toLight`  points from a cloud toward the light, with y running down.
// `fade`     the y, in points, where the clouds start to thin out, and where
//            they're gone. On the way they break up into fewer and smaller
//            clouds, and fade, rather than fading evenly across the view.
//            Equal values leave them as they are.
[[ stitchable ]]
half4 cloudDrift(float2 position,
                 half4 color,
                 float2 size,
                 float unit,
                 float time,
                 float cover,
                 float seed,
                 half4 lit,
                 half4 shade,
                 float2 toLight,
                 float2 fade)
{
    float amount = clamp(cover, 0.0, 1.0);
    // 0 above where the clouds thin out, 1 where they're gone
    float thinning = fade.y > fade.x ? smoothstep(fade.x, fade.y, position.y) : 0.0;
    // What's left of them fades as they go
    float presence = smoothstep(0.0, 0.2, amount) * float(color.a) * (1.0 - smoothstep(0.4, 1.0, thinning));
    if (presence <= 0.0) {
        return half4(0.0h);
    }

    // The clouds are wider than they are tall
    float2 uv = position * float2(1.1, 1.485) / max(unit, 1.0);
    // 0 at the top edge, 1 at the bottom
    float down = clamp(position.y / max(size.y, 1.0), 0.0, 1.0);

    float t = time * 0.036;
    float2 light = toLight / max(length(toLight), 0.001);

    // The field's values bunch around 0.5; the threshold moves down through
    // them to let more of the field count as cloud.
    float threshold = mix(0.70, 0.30, amount);

    // Each layer's lattice is turned away from the view's edges, and from
    // the other layer's.
    const float2x2 nearTurn = float2x2(0.921, 0.389, -0.389, 0.921);
    const float2x2 farTurn = float2x2(0.809, -0.588, 0.588, 0.809);

    // Haze thins the clouds toward the horizon
    float haze = (1.0 - 0.25 * down) * presence;
    // Under a full deck less direct light gets through
    half3 direct = mix(lit.rgb, shade.rgb, half(0.3 * smoothstep(0.6, 0.95, amount)));

    // Near layer, with more of its clouds toward the top
    float2 nearPoint = nearTurn * (uv + float2(seed * 289.0 - t, seed * 173.0));
    clouds::Layer near = clouds::layer(nearPoint,
                                       t,
                                       threshold + 0.06 * (down - 0.5),
                                       thinning,
                                       nearTurn * light * 0.18,
                                       true);
    half nearAlpha = half(near.coverage * 0.95 * haze);
    half3 rgb = mix(shade.rgb, direct, half(near.light)) * nearAlpha;
    half alpha = nearAlpha;

    // Far layer: smaller, slower and fainter, with more of its clouds
    // toward the horizon. It shows only where there's no near cloud.
    if (near.coverage < 1.0) {
        float2 farPoint = farTurn * (uv * 1.9 + float2(seed * 431.0 + 40.0 - t * 0.5, seed * 251.0 + 17.0));
        clouds::Layer far = clouds::layer(farPoint,
                                          t * 0.6,
                                          threshold + 0.02 - 0.10 * (down - 0.5),
                                          thinning,
                                          float2(0.0),
                                          false);
        half farAlpha = half(far.coverage * 0.6 * haze * (1.0 - near.coverage));
        rgb += mix(shade.rgb, direct, half(far.light)) * farAlpha;
        alpha += farAlpha;
    }

    return half4(rgb, alpha);
}
