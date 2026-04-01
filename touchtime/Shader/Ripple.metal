/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A shader that applies a ripple effect to a view when using it as a SwiftUI layer
 effect.
*/

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    // The distance of the current pixel position from `origin`.
    float distance = length(position - origin);
    // The amount of time it takes for the ripple to arrive at the current pixel position.
    float delay = distance / speed;

    // Adjust for delay, clamp to 0.
    time -= delay;
    time = max(0.0, time);

    // The ripple is a sine wave that Metal scales by an exponential decay
    // function.
    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);

    // A vector of length `amplitude` that points away from position.
    float2 n = normalize(position - origin);

    // Scale `n` by the ripple amount at the current pixel position and add it
    // to the current pixel position.
    //
    // This new position moves toward or away from `origin` based on the
    // sign and magnitude of `rippleAmount`.
    float2 newPosition = position + rippleAmount * n;

    // Sample the layer at the new position.
    half4 color = layer.sample(newPosition);

    // Lighten or darken the color based on the ripple amount and its alpha
    // component.
    color.rgb += 0.3 * (rippleAmount / amplitude) * color.a;

    return color;
}

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
    float shift = 5.0 * strength; //色差位移

    float2 offset = float2(shift * direction, 0.0);

    half4 redSample = layer.sample(position - offset);
    half4 blueSample = layer.sample(position + offset);

    half3 splitColor = half3(redSample.r, base.g, blueSample.b);
    half3 mixedColor = mix(base.rgb, splitColor, half(strength));

    // Slightly brighten highlights so the split reads as red/white/blue.
    mixedColor = mix(mixedColor, half3(1.0), half(0.12 * strength * base.a));

    return half4(mixedColor, base.a);
}
