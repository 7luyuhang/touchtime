//
//  ParticleSystem.swift
//  GrokOnboarding
//
//  Created on 06/10/2025.
//

import SwiftUI
import MetalKit

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var life: Float
    var size: Float
    var opacity: Float
}

enum ParticleMotionDirection {
    case bottomToTop
    case rightToLeft
}

class ParticleSystemRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    
    var particles: [Particle] = []
    let maxParticles = 100 // 增加粒子数量
    var particleBuffer: MTLBuffer?
    
    var viewSize: SIMD2<Float> = SIMD2<Float>(0, 0)
    var lastUpdateTime: TimeInterval = 0
    var isReady = false // 标记粒子系统是否准备就绪
    
    // 粒子颜色 (默认白色)
    var particleColor: SIMD3<Float> = SIMD3<Float>(1.0, 1.0, 1.0)
    var motionDirection: ParticleMotionDirection = .bottomToTop
    
    override init() {
        super.init()
        setupMetal()
        // 不在这里初始化粒子，等待获得正确的视图尺寸
    }
    
    init(color: SIMD3<Float>) {
        self.particleColor = color
        super.init()
        setupMetal()
    }

    init(color: SIMD3<Float>, direction: ParticleMotionDirection) {
        self.particleColor = color
        self.motionDirection = direction
        super.init()
        setupMetal()
    }
    
    func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        let vertexFunction = library.makeFunction(name: "particleVertex")
        let fragmentFunction = library.makeFunction(name: "particleFragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 启用混合以支持透明度
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }
    
    func initializeParticles() {
        // 只有当 viewSize 有效时才初始化粒子
        guard viewSize.x > 0 && viewSize.y > 0 else {
            return
        }
        
        particles.removeAll()
        for _ in 0..<maxParticles {
            // 初始化时，粒子在全屏范围内生成
            var particle = createParticle(fromBottom: false)
            // 随机化生命周期，让粒子不会同时消失
            particle.life = Float.random(in: 0.5...2.0) // 更长的随机生命周期
            particles.append(particle)
        }
        
        // 标记系统已准备就绪
        isReady = true
    }
    
    func createParticle(fromBottom: Bool = true) -> Particle {
        // 使用实际的 viewSize，不设置默认值
        let x: Float
        let y: Float
        let speedX: Float
        let speedY: Float
        let size: Float
        let opacity: Float

        switch motionDirection {
        case .bottomToTop:
            x = Float.random(in: 0...viewSize.x)

            if fromBottom {
                // 从底部生成新粒子
                y = Float.random(in: viewSize.y + 50...viewSize.y + 200)
            } else {
                // 在屏幕范围内随机位置生成
                y = Float.random(in: -200...viewSize.y + 200)
            }

            speedX = Float.random(in: -30...30)
            speedY = Float.random(in: -150...(-80)) // 向上移动
            size = Float.random(in: 10...20)
            opacity = Float.random(in: 0.5...1.0)

        case .rightToLeft:
            if fromBottom {
                x = Float.random(in: (viewSize.x + 40)...(viewSize.x + 160))
            } else {
                x = Float.random(in: (-160)...(viewSize.x + 160))
            }
            y = Float.random(in: 0...viewSize.y)
            speedX = Float.random(in: -150...(-80))
            speedY = Float.random(in: -18...18)
            size = Float.random(in: 8...16)
            opacity = Float.random(in: 0.45...0.9)
        }

        return Particle(
            position: SIMD2<Float>(x, y),
            velocity: SIMD2<Float>(speedX, speedY),
            life: 1.5, // 增加初始生命值，让粒子活得更久
            size: size,
            opacity: opacity
        )
    }
    
    func updateParticles(deltaTime: Float) {
        // 确保系统准备就绪后才更新粒子
        guard isReady && viewSize.x > 0 && viewSize.y > 0 else { return }
        
        for i in 0..<particles.count {
            particles[i].position += particles[i].velocity * deltaTime
            particles[i].life -= deltaTime * 0.15 // 减缓生命衰减速度
            
            let shouldRespawn: Bool
            switch motionDirection {
            case .bottomToTop:
                // 如果粒子死亡或移出屏幕顶部，重新生成
                shouldRespawn = particles[i].life <= 0 || particles[i].position.y < -500
            case .rightToLeft:
                shouldRespawn = particles[i].life <= 0 || particles[i].position.x < -500
            }

            if shouldRespawn {
                particles[i] = createParticle(fromBottom: motionDirection == .rightToLeft)
                // 重置生命值确保粒子能够显示
                particles[i].life = 1.5 // 与初始生命值保持一致
            }
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let newSize = SIMD2<Float>(Float(size.width), Float(size.height))
        
        // 只有当尺寸真正改变时才更新
        if newSize.x > 0 && newSize.y > 0 && (viewSize.x != newSize.x || viewSize.y != newSize.y) {
            viewSize = newSize
            
            // 如果还没有初始化粒子，现在初始化
            if !isReady {
                initializeParticles()
            }
        }
    }
    
    func draw(in view: MTKView) {
        // 确保有正确的视图大小
        if viewSize.x == 0 || viewSize.y == 0 {
            let newSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            if newSize.x > 0 && newSize.y > 0 {
                viewSize = newSize
                initializeParticles()
            }
            return // 在尺寸设置前不绘制
        }
        
        // 如果系统还没准备好，不绘制
        guard isReady else { return }
        
        let currentTime = CACurrentMediaTime()
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let deltaTime = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        
        updateParticles(deltaTime: deltaTime)
        
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        // 设置清除颜色（透明）
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        particleBuffer = device.makeBuffer(bytes: particles, length: MemoryLayout<Particle>.stride * particles.count, options: [])
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewSize, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderEncoder.setVertexBytes(&particleColor, length: MemoryLayout<SIMD3<Float>>.stride, index: 2)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

struct ParticleView: UIViewRepresentable {
    var color: Color = .white
    var direction: ParticleMotionDirection = .bottomToTop
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.contentMode = .scaleToFill // 确保填满整个视图
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
    
    func makeCoordinator() -> ParticleSystemRenderer {
        // 将 SwiftUI Color 转换为 SIMD3<Float>
        let uiColor = UIColor(color)
        var red: CGFloat = 1.0
        var green: CGFloat = 1.0
        var blue: CGFloat = 1.0
        var alpha: CGFloat = 1.0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorSIMD = SIMD3<Float>(Float(red), Float(green), Float(blue))
        return ParticleSystemRenderer(color: colorSIMD, direction: direction)
    }
}

