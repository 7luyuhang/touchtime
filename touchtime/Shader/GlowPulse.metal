//
//  GlowPulse.metal
//  touchtime
//
//  A one-shot white glow that rises from the bottom edge and pulses.
//  Used as a SwiftUI colorEffect on a full-bleed overlay.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// `size`      view size in points.
// `progress`  animation progress in [0, 1].
// `intensity` overall strength in [0, 1].
[[ stitchable ]]
half4 glowPulse(float2 position,
                half4 color,
                float2 size,
                float progress,
                float intensity)
{
    float w = max(size.x, 1.0);
    float h = max(size.y, 1.0);

    // 0 at the bottom edge, 1 at the top edge.
    float y = clamp(1.0 - position.y / h, 0.0, 1.0);

    // Leading edge climbs from the bottom past the top, so the light
    // "expands upward" as the animation plays.
    float reach = progress * 1.25;

    // Falloff widens as the glow rises: crisp at the bottom, diffuse on top.
    float softness = mix(0.06, 0.5, progress);

    // Filled wash below the leading edge, brightest near the bottom.
    float wash = 1.0 - smoothstep(reach - softness, reach + softness, y);

    // Bright soft halo riding the leading edge.
    float d = (y - reach) / max(softness, 0.001);
    float halo = exp(-d * d);

    // Gentle center bias so it reads as a bloom, not a flat bar.
    float xc = (position.x / w - 0.5) * 2.0;
    float horiz = 1.0 - 0.35 * xc * xc;

    // Single fade-in / peak / fade-out across the whole animation.
    float env = pow(max(sin(progress * 3.14159265), 0.0), 0.65);

    float glow = (wash * 0.55 + halo * 0.9) * horiz * env;
    float a = clamp(glow * intensity, 0.0, 1.0);

    // Premultiplied white.
    return half4(half3(a), a);
}
