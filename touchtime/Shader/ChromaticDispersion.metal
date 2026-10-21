//
//  ChromaticDispersion.metal
//  touchtime
//
//  Splits a layer into seven spectral bands, red to violet, pushed apart
//  from its center like light through a lens: not at all at the center,
//  most at the edges. Used as a SwiftUI layerEffect.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// `layerSize` view size in points.
// `strength`  amount of the split in [0, 1].
// `maxShift`  how far, in points, red moves out and violet moves in at the
//             edge of the layer's inscribed circle when `strength` is 1.
[[ stitchable ]]
half4 ChromaticDispersion(
    float2 position,
    SwiftUI::Layer layer,
    float2 layerSize,
    float strength,
    float maxShift
) {
    half4 base = layer.sample(position);

    if (strength <= 0.0001) {
        return base;
    }

    float2 center = layerSize * 0.5;
    float radius = max(min(layerSize.x, layerSize.y) * 0.5, 1.0);
    float2 offset = (position - center) / radius * maxShift * strength;

    const half3 spectrum[7] = {
        half3(1.0, 0.0, 0.0), // red
        half3(1.0, 0.5, 0.0), // orange
        half3(1.0, 1.0, 0.0), // yellow
        half3(0.0, 1.0, 0.0), // green
        half3(0.0, 1.0, 1.0), // cyan
        half3(0.0, 0.0, 1.0), // blue
        half3(0.5, 0.0, 1.0)  // violet
    };

    half3 color = half3(0.0);
    half3 weight = half3(0.0);
    half alpha = 0.0;

    for (int i = 0; i < 7; i++) {
        // Red samples furthest in, so it lands furthest out; violet the reverse
        float t = 1.0 - float(i) / 3.0;
        half4 tap = layer.sample(position - offset * t);
        color += tap.rgb * spectrum[i];
        weight += spectrum[i];
        alpha += tap.a;
    }

    // Each band carries a seventh of the light, so the bands are brightened
    // as they part to keep reading as colours
    color = color / weight * half(1.0 + 1.2 * strength);

    return half4(color, alpha / 7.0);
}
