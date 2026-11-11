import SceneKit
import SwiftUI
import Metal
#if DEBUG
import os
#endif

/// The watch app's detail views, in the order taps on the screen show them.
nonisolated enum AppleWatchPreviewScreen: CaseIterable {
    case worldClock
    case solarCurve
    case sunPosition
    case daylight
    case moonPhase

    // Matches CityDetailDisplay's titles in the watch app
    var title: String {
        switch self {
        case .worldClock: String(localized: "World Map")
        case .solarCurve: String(localized: "Solar Curve")
        case .sunPosition: String(localized: "Sun Position")
        case .daylight: String(localized: "Daylight")
        case .moonPhase: String(localized: "Moon Phase")
        }
    }

    var imageName: String {
        switch self {
        case .worldClock: "AppleWatchIntroWorldClock"
        case .solarCurve: "AppleWatchIntroSolarCurve"
        case .sunPosition: "AppleWatchIntroSunPosition"
        case .daylight: "AppleWatchIntroDaylight"
        case .moonPhase: "AppleWatchIntroMoonPhase"
        }
    }
}

/// Uses the supplied USDZ's actual display mesh, so the screenshot stays
/// attached to the watch face throughout the three-dimensional entrance.
/// Tapping the screen crossfades through the watch app's views.
struct AppleWatchMockupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var scene: SCNScene?
    @State private var loadFailed = false
    @State private var entranceHasStarted = false
    private let onScreenChange: (AppleWatchPreviewScreen) -> Void

    init(onScreenChange: @escaping (AppleWatchPreviewScreen) -> Void = { _ in }) {
        self.onScreenChange = onScreenChange
    }

    static func preload() async {
        await AppleWatchSceneCache.shared.preload()
    }

    var body: some View {
        ZStack {
            if let scene {
                AppleWatchSceneView(
                    scene: scene,
                    reduceMotion: reduceMotion,
                    hapticEnabled: hapticEnabled,
                    onScreenChange: onScreenChange
                ) {
                    entranceHasStarted = true
                }
                .blur(radius: reduceMotion || entranceHasStarted ? 0 : 10)
                .animation(reduceMotion ? nil : .easeOut(duration: 1.2), value: entranceHasStarted)
            } else if loadFailed {
                // Keep the introduction useful if a bundled asset cannot load.
                Image(AppleWatchPreviewScreen.allCases[0].imageName)
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
            guard let url = Bundle.main.url(forResource: "apple-watch-series-10-titanium-gold", withExtension: "usdz") else {
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
    let hapticEnabled: Bool
    let onScreenChange: (AppleWatchPreviewScreen) -> Void
    let onEntranceBegan: () -> Void

    nonisolated private static let watchNodeName = "introWatch"
    nonisolated private static let rotationNodeName = "introWatchRotation"
    nonisolated private static let cameraNodeName = "introCamera"
    nonisolated private static let displayNodeName = "rJeLKgtaspBNkmI"
    // The screen material holds two screenshots, the diffuse one and an
    // incoming one, and mixes between them by the fade amount.
    nonisolated private static let incomingScreenKey = "incomingScreen"
    nonisolated private static let screenFadeKey = "screenFade"
    nonisolated private static let screenFadeModifier = """
        #pragma arguments
        texture2d<float> \(incomingScreenKey);
        float \(screenFadeKey);
        #pragma body
        constexpr sampler screenSampler(filter::linear, mip_filter::linear, max_anisotropy(8));
        float4 incoming = \(incomingScreenKey).sample(screenSampler, _surface.diffuseTexcoord);
        _surface.diffuse = mix(_surface.diffuse, incoming, \(screenFadeKey));
        """
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
        coordinator.hapticEnabled = hapticEnabled
        coordinator.onScreenChange = onScreenChange
        coordinator.rotationNode = scene.rootNode.childNode(withName: Self.rotationNodeName, recursively: true)
        if let display = scene.rootNode.childNode(withName: Self.displayNodeName, recursively: true) {
            coordinator.attachScreen(display)
        }
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:))))

        guard let watch = scene.rootNode.childNode(withName: Self.watchNodeName, recursively: false) else {
            return view
        }

        if !reduceMotion {
            watch.position.y = -3
            watch.eulerAngles = Self.entranceAngles
            watch.scale = SCNVector3(0.85, 0.85, 0.85)
        }

        // The shared cache has already drawn resting and entrance poses. Prepare
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
                watch.runAction(.sequence([movement, settle])) { [weak coordinator] in
                    DispatchQueue.main.async {
                        coordinator?.isReady = true
                        coordinator?.pauseIfIdle()
                    }
                }
            }
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.reduceMotion = reduceMotion
        context.coordinator.hapticEnabled = hapticEnabled
        context.coordinator.onScreenChange = onScreenChange
        if reduceMotion, let watch = scene.rootNode.childNode(withName: Self.watchNodeName, recursively: false) {
            watch.removeAllActions()
            watch.position = SCNVector3Zero
            watch.eulerAngles = Self.restingAngles
            watch.scale = SCNVector3(1, 1, 1)
            context.coordinator.isReady = true
            context.coordinator.pauseIfIdle()
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.isReady = false
        coordinator.rotationNode?.removeAllActions()
        coordinator.displayNode?.removeAllActions()
        coordinator.view = nil
        view.scene?.rootNode.childNode(withName: watchNodeName, recursively: false)?.removeAllActions()
        view.isPlaying = false
        view.scene = nil
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var view: SCNView?
        weak var rotationNode: SCNNode?
        weak var displayNode: SCNNode?
        var reduceMotion = false
        var hapticEnabled = true
        var onScreenChange: (AppleWatchPreviewScreen) -> Void = { _ in }
        var isReady = false
        private var isDragging = false
        private var startingYaw: Float = 0
        private var resetID = UUID()
        private let maximumYaw = Float.pi / 12
        private static let screenFadeActionKey = "screenFade"
        private var screenIndex = 0
        // Whether the incoming slot, rather than the diffuse one, holds the
        // screenshot on screen; each tap fades the hidden slot in.
        private var showsIncomingScreen = false

        func attachScreen(_ display: SCNNode) {
            // Clones share geometry and materials with the cached template, so
            // switching screenshots needs this view's own copies.
            guard let geometry = display.geometry?.copy() as? SCNGeometry,
                  let material = geometry.firstMaterial?.copy() as? SCNMaterial else { return }
            geometry.materials = [material]
            display.geometry = geometry
            displayNode = display
        }

        /// Rendering stops only once the entrance, any drag and its reset, and
        /// any screen fade have all finished, so none of them freezes another.
        func pauseIfIdle() {
            guard let view, !isDragging else { return }
            let watch = view.scene?.rootNode.childNode(withName: AppleWatchSceneView.watchNodeName, recursively: false)
            guard ![watch, rotationNode, displayNode].contains(where: { $0?.hasActions == true }) else { return }
            view.isPlaying = false
        }

        @objc func handleTap(_ tap: UITapGestureRecognizer) {
            guard let view, let displayNode else { return }
            // The display mesh is made of polygons, which SceneKit's mesh hit
            // testing skips; its thin bounding box covers exactly the screen.
            let hits = view.hitTest(tap.location(in: view), options: [.rootNode: displayNode, .boundingBoxOnly: true])
            guard !hits.isEmpty else { return }
            showNextScreen()
        }

        private func showNextScreen() {
            guard let view, let displayNode, let material = displayNode.geometry?.firstMaterial else { return }
            let screens = AppleWatchPreviewScreen.allCases
            let nextIndex = (screenIndex + 1) % screens.count
            guard let screenshot = UIImage(named: screens[nextIndex].imageName) else { return }
            screenIndex = nextIndex
            onScreenChange(screens[nextIndex])

            // A tap mid-fade settles the running fade before starting the next.
            displayNode.removeAction(forKey: Self.screenFadeActionKey)
            let start: CGFloat = showsIncomingScreen ? 1 : 0
            material.setValue(start, forKey: AppleWatchSceneView.screenFadeKey)
            if showsIncomingScreen {
                material.diffuse.contents = screenshot
            } else {
                material.setValue(AppleWatchSceneView.screenTexture(screenshot), forKey: AppleWatchSceneView.incomingScreenKey)
            }
            showsIncomingScreen.toggle()
            let end: CGFloat = showsIncomingScreen ? 1 : 0

            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            let duration: TimeInterval = 0.3
            let fade = SCNAction.customAction(duration: duration) { node, elapsed in
                let progress = min(elapsed / CGFloat(duration), 1)
                let eased = progress * progress * (3 - 2 * progress)
                node.geometry?.firstMaterial?.setValue(start + (end - start) * eased, forKey: AppleWatchSceneView.screenFadeKey)
            }
            let settle = SCNAction.run { node in
                node.geometry?.firstMaterial?.setValue(end, forKey: AppleWatchSceneView.screenFadeKey)
            }
            view.isPlaying = true
            displayNode.runAction(.sequence([fade, settle]), forKey: Self.screenFadeActionKey) { [weak self] in
                DispatchQueue.main.async {
                    self?.pauseIfIdle()
                }
            }
        }

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
                isDragging = true
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
                isDragging = false
                if reduceMotion {
                    rotationNode.eulerAngles = SCNVector3Zero
                    pauseIfIdle()
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
                        self.pauseIfIdle()
                    }
                }
            default:
                break
            }
        }
    }

    nonisolated static func configure(_ scene: SCNScene) throws -> SCNScene {
        let screens = AppleWatchPreviewScreen.allCases
        guard let screenshot = UIImage(named: screens[0].imageName),
              let nextScreenshot = UIImage(named: screens[1].imageName),
              let display = scene.rootNode.childNode(withName: displayNodeName, recursively: true),
              let displayGeometry = display.geometry else {
            throw WatchSceneError.missingAsset
        }

        let screenMaterial = SCNMaterial()
        screenMaterial.lightingModel = .constant
        screenMaterial.diffuse.contents = screenshot
        screenMaterial.diffuse.mipFilter = .linear
        screenMaterial.diffuse.maxAnisotropy = 8
        // Bind the incoming slot up front so warm-up compiles the fade shader
        // and uploads the first screenshot a tap brings in.
        screenMaterial.shaderModifiers = [.surface: screenFadeModifier]
        screenMaterial.setValue(screenTexture(nextScreenshot), forKey: incomingScreenKey)
        // A floating-point value like the fade's; SceneKit stops updating a
        // uniform whose value type changes.
        screenMaterial.setValue(0.0, forKey: screenFadeKey)
        // Retain the mesh's original full-screen UVs and rounded outline.
        displayGeometry.materials = [screenMaterial]
        applyWhiteAluminum(to: scene)

        let source = SCNNode()
        for child in scene.rootNode.childNodes {
            source.addChildNode(child)
        }
        // Rotate the USDZ's tilted display upright.
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

    nonisolated private static func screenTexture(_ screenshot: UIImage) -> SCNMaterialProperty {
        let texture = SCNMaterialProperty(contents: screenshot)
        texture.mipFilter = .linear
        return texture
    }

    nonisolated private static func applyWhiteAluminum(to scene: SCNScene) {
        // The Series 10 asset's case, crown, buttons and metal trim.
        let metalMaterialNames: Set<String> = [
            "LWJHeYYQMRZxZCG", "KMfhfHsSQFxApYe", "tetEWTOUCivgKZc",
            "HsVxdnblPfZrHgy", "EGNcJKGscUKkYej", "KJKkRClRaugvehP",
            "ujcnrIOZEjyiFMV", "NkcEzuWLLNYoZWe", "PiEVCjonPhxlRAO",
            "sgaomdeDGcIyeqa"
        ]
        let aluminumColor = UIColor(white: 0.85, alpha: 1)

        scene.rootNode.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                guard let name = material.name, metalMaterialNames.contains(name) else { continue }
                material.lightingModel = .physicallyBased
                material.diffuse.contents = aluminumColor
                material.metalness.contents = 0.85
                material.roughness.contents = 0.5
            }
        }
    }

    nonisolated static func warmUp(_ scene: SCNScene) -> SCNRenderer {
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: cameraNodeName, recursively: false)
        _ = renderer.prepare(scene, shouldAbortBlock: nil)

        // Actual draws also warm lazy shader/pipeline variants, beyond texture
        // upload. Match the view's antialiasing and exercise the entrance pose.
        let size = CGSize(width: 400, height: 300)
        autoreleasepool {
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        }
        if let watch = scene.rootNode.childNode(withName: watchNodeName, recursively: false) {
            watch.eulerAngles = entranceAngles
            autoreleasepool {
                _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            }
            watch.eulerAngles = restingAngles
        }
        return renderer
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
