#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 EdgeRGBSplit(
    float2 position,
    SwiftUI::Layer layer,
    float2 layerSize,
    float edgeProgress,
    float direction
) {
    half4 base = layer.sample(position);

    if (edgeProgress <= 0.0001) {
        return base;
    }

    float2 safeSize = max(layerSize, float2(1.0, 1.0));
    float2 uv = position / safeSize;

    // Stronger near each page edge, weaker near the page center.
    float edgeMask = pow(abs(uv.x * 2.0 - 1.0), 1.4);
    float strength = clamp(edgeProgress * edgeMask, 0.0, 1.0);
    float shift = 2.5 * strength; // 色差位移

    float2 offset = float2(shift * direction, 0.0);

    half4 redSample = layer.sample(position - offset);
    half4 blueSample = layer.sample(position + offset);

    half3 splitColor = half3(redSample.r, base.g, blueSample.b);
    half3 mixedColor = mix(base.rgb, splitColor, half(strength));

    // Slightly brighten highlights so the split reads as red/white/blue.
    mixedColor = mix(mixedColor, half3(1.0), half(0.12 * strength * base.a));

    return half4(mixedColor, base.a);
}
