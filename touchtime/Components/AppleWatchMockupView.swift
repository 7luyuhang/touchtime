import SceneKit
import SwiftUI
import Metal
#if DEBUG
import os
#endif

/// Uses the supplied USDZ's actual display mesh, so the screenshot stays
/// attached to the watch face throughout the three-dimensional entrance.
struct AppleWatchMockupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: SCNScene?
    @State private var loadFailed = false
    @State private var entranceHasStarted = false

    static func preload() async {
        await AppleWatchSceneCache.shared.preload()
    }

    var body: some View {
        ZStack {
            if let scene {
                AppleWatchSceneView(scene: scene, reduceMotion: reduceMotion) {
                    entranceHasStarted = true
                }
                .blur(radius: reduceMotion || entranceHasStarted ? 0 : 10)
                .animation(reduceMotion ? nil : .easeOut(duration: 1.2), value: entranceHasStarted)
            } else if loadFailed {
                // Keep the introduction useful if a bundled asset cannot load.
                Image("AppleWatchIntroScreen")
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            } else {
                Color.clear
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Apple Watch showing TouchTime world clocks and time adjustment"))
        .task {
            guard scene == nil else { return }
            do {
                scene = try await AppleWatchSceneCache.shared.makeScene()
            } catch is CancellationError {
                // Dismissal can cancel the task while the USDZ is decoding.
            } catch {
                loadFailed = true
            }
        }
    }
}

/// One preparation job shared by both entry points. Geometry and materials
/// stay cached; each sheet gets its own nodes for entrance and drag animations.
@MainActor
private final class AppleWatchSceneCache {
    static let shared = AppleWatchSceneCache()
    private var preparationTask: Task<PreparedScene, Error>?

    private struct PreparedScene {
        let scene: SCNScene
        // Retain the warm renderer and its GPU resources with the template.
        let renderer: SCNRenderer
    }

    func preload() async {
        _ = try? await preparedScene()
    }

    func makeScene() async throws -> SCNScene {
        let prepared = try await preparedScene()
        try Task.checkCancellation()
        let scene = SCNScene()
        for child in prepared.scene.rootNode.childNodes {
            scene.rootNode.addChildNode(child.clone())
        }
        scene.background.contents = UIColor.clear
        return scene
    }

    private func preparedScene() async throws -> PreparedScene {
        if let preparationTask {
            return try await preparationTask.value
        }
        let task = Task.detached(priority: .utility) {
            #if DEBUG
            let start = CFAbsoluteTimeGetCurrent()
            #endif
            guard let url = Bundle.main.url(forResource: "apple-watch-ultra-2", withExtension: "usdz") else {
                throw WatchSceneError.missingAsset
            }
            let scene = try AppleWatchSceneView.configure(SCNScene(url: url))
            #if DEBUG
            let decoded = CFAbsoluteTimeGetCurrent()
            #endif
            let renderer = AppleWatchSceneView.warmUp(scene)
            #if DEBUG
            let warm = CFAbsoluteTimeGetCurrent()
            Logger(subsystem: "com.time.touchtime", category: "AppleWatchPreview").info(
                "Preview prepared: decode/configure \(decoded - start, privacy: .public)s, GPU warm-up \(warm - decoded, privacy: .public)s"
            )
            #endif
            return PreparedScene(scene: scene, renderer: renderer)
        }
        preparationTask = task
        do {
            return try await task.value
        } catch {
            preparationTask = nil
            throw error
        }
    }
}

private enum WatchSceneError: Error {
    case missingAsset
}

private struct AppleWatchSceneView: UIViewRepresentable {
    let scene: SCNScene
    let reduceMotion: Bool
    let onEntranceBegan: () -> Void

    nonisolated private static let watchNodeName = "introWatch"
    nonisolated private static let rotationNodeName = "introWatchRotation"
    nonisolated private static let cameraNodeName = "introCamera"
    // Settle face-on and upright so the screen remains easy to read.
    nonisolated private static let restingAngles = SCNVector3Zero
    nonisolated private static let entranceAngles = SCNVector3(-0.45, -0.65, -0.18)
    nonisolated private static let entranceDuration: TimeInterval = 2.0

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: Self.cameraNodeName, recursively: false)

        let coordinator = context.coordinator
        coordinator.view = view
        coordinator.reduceMotion = reduceMotion
        coordinator.rotationNode = scene.rootNode.childNode(withName: Self.rotationNodeName, recursively: true)
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        guard let watch = scene.rootNode.childNode(withName: Self.watchNodeName, recursively: false) else {
            return view
        }

        if !reduceMotion {
            watch.opacity = 0
            watch.position.y = -3
            watch.eulerAngles = Self.entranceAngles
            watch.scale = SCNVector3(0.85, 0.85, 0.85)
        }

        // The shared cache has already drawn opaque and fading frames. Prepare
        // this view's resources before starting its independent entrance.
        view.prepare([scene]) { [weak view, weak coordinator] _ in
            DispatchQueue.main.async {
                guard let view, view.scene != nil, let coordinator else { return }
                onEntranceBegan()
                guard !coordinator.reduceMotion else {
                    coordinator.isReady = true
                    return
                }
                let spring = Spring(settlingDuration: Self.entranceDuration, dampingRatio: 0.72)
                // Sample the spring directly: SCNAction timing functions require
                // monotonic progress and cannot express the spring's overshoot.
                let movement = SCNAction.customAction(duration: Self.entranceDuration) { node, elapsed in
                    let progress = Float(spring.value(target: 1.0, time: Double(elapsed)))
                    let remaining = 1 - progress
                    node.position = SCNVector3(0, -3 * remaining, 0)
                    node.eulerAngles = SCNVector3(
                        Self.entranceAngles.x * remaining,
                        Self.entranceAngles.y * remaining,
                        Self.entranceAngles.z * remaining
                    )
                    let scale = 0.85 + 0.15 * progress
                    node.scale = SCNVector3(scale, scale, scale)
                }
                let settle = SCNAction.run { node in
                    node.position = SCNVector3Zero
                    node.eulerAngles = Self.restingAngles
                    node.scale = SCNVector3(1, 1, 1)
                }
                view.isPlaying = true
                watch.runAction(.group([.sequence([movement, settle]), .fadeIn(duration: 0.8)])) { [weak view, weak coordinator] in
                    DispatchQueue.main.async {
                        view?.isPlaying = false
                        coordinator?.isReady = true
                    }
                }
            }
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.reduceMotion = reduceMotion
        if reduceMotion, let watch = scene.rootNode.childNode(withName: Self.watchNodeName, recursively: false) {
            watch.removeAllActions()
            watch.opacity = 1
            watch.position = SCNVector3Zero
            watch.eulerAngles = Self.restingAngles
            watch.scale = SCNVector3(1, 1, 1)
            view.isPlaying = false
            context.coordinator.isReady = true
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.isReady = false
        coordinator.rotationNode?.removeAllActions()
        coordinator.view = nil
        view.scene?.rootNode.childNode(withName: watchNodeName, recursively: false)?.removeAllActions()
        view.isPlaying = false
        view.scene = nil
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var view: SCNView?
        weak var rotationNode: SCNNode?
        var reduceMotion = false
        var isReady = false
        private var startingYaw: Float = 0
        private var resetID = UUID()
        private let maximumYaw = Float.pi / 12

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isReady, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: view)
            // Leave vertical swipes to the sheet's interactive dismissal.
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            guard let view, let rotationNode else { return }
            switch pan.state {
            case .began:
                resetID = UUID()
                let currentYaw = rotationNode.presentation.eulerAngles.y
                rotationNode.removeAllActions()
                rotationNode.eulerAngles.y = currentYaw
                startingYaw = currentYaw
                view.isPlaying = true
            case .changed:
                let distance = Float(pan.translation(in: view).x / max(view.bounds.width, 1))
                let yaw = startingYaw + distance * maximumYaw * 2
                rotationNode.eulerAngles.y = min(max(yaw, -maximumYaw), maximumYaw)
            case .ended, .cancelled, .failed:
                if reduceMotion {
                    rotationNode.eulerAngles = SCNVector3Zero
                    view.isPlaying = false
                    return
                }
                let currentResetID = UUID()
                resetID = currentResetID
                let yaw = rotationNode.eulerAngles.y
                let duration = 0.55
                let spring = Spring(settlingDuration: duration, dampingRatio: 0.8)
                let reset = SCNAction.customAction(duration: duration) { node, elapsed in
                    let progress = Float(spring.value(target: 1.0, time: Double(elapsed)))
                    node.eulerAngles.y = yaw * (1 - progress)
                }
                let settle = SCNAction.run { node in
                    node.eulerAngles = SCNVector3Zero
                }
                rotationNode.runAction(.sequence([reset, settle])) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self, self.resetID == currentResetID else { return }
                        self.view?.isPlaying = false
                    }
                }
            default:
                break
            }
        }
    }

    nonisolated static func configure(_ scene: SCNScene) throws -> SCNScene {
        guard let screenshot = UIImage(named: "AppleWatchIntroScreen"),
              let display = scene.rootNode.childNode(withName: "EoJqLMCyQtOSdnP", recursively: true),
              let displayGeometry = display.geometry else {
            throw WatchSceneError.missingAsset
        }

        let screenMaterial = SCNMaterial()
        screenMaterial.lightingModel = .constant
        screenMaterial.diffuse.contents = screenshot
        screenMaterial.diffuse.mipFilter = .linear
        screenMaterial.diffuse.maxAnisotropy = 8
        // Retain the mesh's original full-screen UVs and rounded outline.
        displayGeometry.materials = [screenMaterial]
        applyBlackTitanium(to: scene.rootNode)

        let source = SCNNode()
        for child in scene.rootNode.childNodes {
            source.addChildNode(child)
        }
        // The USDZ is tilted 55° about X; another 35° makes the face upright.
        source.eulerAngles.x = .pi * 35 / 180
        let centered = SCNNode()
        centered.addChildNode(source)
        let bounds = display.boundingBox
        let displayCenter = SCNVector3(
            (bounds.min.x + bounds.max.x) / 2,
            (bounds.min.y + bounds.max.y) / 2,
            (bounds.min.z + bounds.max.z) / 2
        )
        let center = centered.convertPosition(displayCenter, from: display)
        source.position = SCNVector3(-center.x, -center.y, -center.z)

        let watch = SCNNode()
        watch.name = watchNodeName
        watch.eulerAngles = restingAngles
        // Keep drag rotation separate from the entrance animation, with the
        // same display-centered pivot so the face stays in the preview.
        let rotation = SCNNode()
        rotation.name = rotationNodeName
        rotation.addChildNode(centered)
        watch.addChildNode(rotation)
        scene.rootNode.addChildNode(watch)

        let camera = SCNNode()
        camera.name = cameraNodeName
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 32
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 100
        // Move closer to the display-centered origin, letting the band
        // extend beyond the preview while the screen stays fully visible.
        camera.position = SCNVector3(0, 0, 9)
        scene.rootNode.addChildNode(camera)

        addLight(to: scene, type: .ambient, intensity: 700, position: SCNVector3Zero)
        addLight(to: scene, type: .directional, intensity: 1600, position: SCNVector3(-4, 6, 8))
        addLight(to: scene, type: .directional, intensity: 900, position: SCNVector3(5, 1, 5))
        addLight(to: scene, type: .directional, intensity: 1400, position: SCNVector3(1, 4, -6))
        scene.background.contents = UIColor.clear
        return scene
    }

    nonisolated static func warmUp(_ scene: SCNScene) -> SCNRenderer {
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: cameraNodeName, recursively: false)
        _ = renderer.prepare(scene, shouldAbortBlock: nil)

        // Actual draws also warm lazy shader/pipeline variants, beyond texture
        // upload. Match the view's antialiasing and exercise the entrance fade.
        let size = CGSize(width: 400, height: 300)
        autoreleasepool {
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        }
        if let watch = scene.rootNode.childNode(withName: watchNodeName, recursively: false) {
            watch.opacity = 0.5
            watch.eulerAngles = entranceAngles
            autoreleasepool {
                _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            }
            watch.opacity = 1
            watch.eulerAngles = restingAngles
        }
        return renderer
    }

    nonisolated private static func applyBlackTitanium(to root: SCNNode) {
        // Exterior metal material names in the supplied USDZ: case, bezel,
        // crown, mesh band and clasp. Keep the display, glass, sensors and
        // orange accents in their original materials.
        let exteriorMetalNames: Set<String> = [
            "QhDiGKCLygjflEJ", "nvGUNsZokLKkYNE", "EdRMiTuJtjEbTqD",
            "OrkvOpfEqsTXAPR", "LqpzWVEGHmdPrjf", "HxWhmpLqfdXlNaj",
            "WmAEsGqmPfbjLQR", "HnhZLEvUrmwFjsr", "hYgYJoDokszsatK",
            "lADxTjzpyhHhnOR"
        ]

        root.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                guard let name = material.name, exteriorMetalNames.contains(name) else { continue }
                // Change only the base color, retaining the original metalness,
                // roughness and normal maps for the brushed metal highlights.
                material.diffuse.contents = UIColor(red: 0.10, green: 0.105, blue: 0.115, alpha: 1)
            }
        }
    }

    nonisolated private static func addLight(to scene: SCNScene, type: SCNLight.LightType, intensity: CGFloat, position: SCNVector3) {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = type
        node.light?.intensity = intensity
        node.position = position
        node.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(node)
    }
}
