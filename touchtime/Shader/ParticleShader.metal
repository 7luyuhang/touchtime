//
//  ParticleShader.metal
//  GrokOnboarding
//
//  Created on 06/10/2025.
//

#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float size;
    float opacity;
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float opacity;
    float3 particleColor;
};

// 简单的随机数生成函数
float random(float2 co) {
    return fract(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
}

vertex VertexOut particleVertex(uint vertexID [[vertex_id]],
                                 constant Particle *particles [[buffer(0)]],
                                 constant float2 &viewSize [[buffer(1)]],
                                 constant float3 &particleColor [[buffer(2)]]) {
    VertexOut out;
    
    Particle particle = particles[vertexID];
    
    // 将粒子位置从像素坐标转换为 NDC（标准化设备坐标）
    float2 normalizedPosition = particle.position / viewSize;
    normalizedPosition = normalizedPosition * 2.0 - 1.0;
    normalizedPosition.y = -normalizedPosition.y; // 翻转 Y 轴
    
    out.position = float4(normalizedPosition, 0.0, 1.0);
    out.pointSize = particle.size;
    out.opacity = particle.opacity * particle.life;
    out.particleColor = particleColor;
    
    return out;
}

fragment float4 particleFragment(VertexOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    // 创建圆形粒子
    float2 center = float2(0.5, 0.5);
    float dist = distance(pointCoord, center);
    
    if (dist > 0.5) {
        discard_fragment();
    }
    
    // 创建发光效果
    float glow = 1.0 - (dist * 2.0);
    glow = pow(glow, 2.0);
    
    // 柔和的边缘
    float alpha = glow * in.opacity;
    
    // 使用传入的颜色
    float3 color = in.particleColor;
    
    return float4(color, alpha);
}

