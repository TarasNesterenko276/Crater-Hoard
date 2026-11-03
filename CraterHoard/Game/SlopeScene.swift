import SpriteKit

/// Receives everything the scene learns while a shift is running.
@MainActor
protocol SlopeSceneDelegate: AnyObject {
    func scene(_ scene: SlopeScene, didUpdate hud: GameHUDState)
    func scene(_ scene: SlopeScene, didRegister event: SessionEvent)
    func scene(_ scene: SlopeScene, didFinishWith summary: RunSummary)
}

/// Draws the volcano, its two rails, the cart and everything the crater throws.
/// All rules live in `RunSession`; the scene forwards input and mirrors the session's state.
final class SlopeScene: SKScene {
    weak var gameDelegate: SlopeSceneDelegate?
    private(set) var session: RunSession
    private let autopilot: Bool

    // Layout (recomputed when the view size changes)
    private var halfTrack: CGFloat = 170
    private var lowerY: CGFloat = 260
    private var upperY: CGFloat = 430
    private var craterPoint = CGPoint(x: 0, y: 720)

    // Nodes
    private let sky = SKSpriteNode(imageNamed: "bg_sky")
    private let volcano = SKSpriteNode(imageNamed: "volcano")
    private let craterGlow = SKSpriteNode(imageNamed: "fx_glow")
    private let ashShade = SKSpriteNode(color: SKColor(red: 0.12, green: 0.1, blue: 0.12, alpha: 1), size: CGSize(width: 10, height: 10))
    private let ashCloud = SKSpriteNode(imageNamed: "ash_cloud")
    private var railNodes: [Rail: SKSpriteNode] = [:]
    private var terraceNodes: [Rail: SKSpriteNode] = [:]
    private var stationNodes: [Rail: SKSpriteNode] = [:]
    private let cart = SKNode()
    private let cartBody = SKSpriteNode(imageNamed: "cart")
    private let cartCargo = SKSpriteNode(imageNamed: "cart_cargo")
    private let cartRider = SKSpriteNode()
    private let cartHeat = SKSpriteNode(imageNamed: "fx_glow")

    private var projectileNodes: [Int: SKSpriteNode] = [:]
    private var shadowNodes: [Int: SKSpriteNode] = [:]
    private var boulderNodes: [Int: SKSpriteNode] = [:]
    private var lightningNodes: [Int: SKSpriteNode] = [:]

    // State
    private var isRunning = false
    private var isSuspended = false
    private var lastUpdate: TimeInterval?
    private var hudAccumulator: TimeInterval = 0
    private var touchStart: (point: CGPoint, time: TimeInterval)?
    private var touchMovedFar = false
    private var lastSwitchFrom: Rail = .lower

    init(size: CGSize, loadout: Loadout, seed: UInt64, autopilot: Bool) {
        session = RunSession(loadout: loadout, seed: seed)
        self.autopilot = autopilot
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0)
        backgroundColor = SKColor(red: 0.16, green: 0.11, blue: 0.14, alpha: 1)
        buildWorld()
        layoutWorld()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public control

    func startRun() {
        guard !isRunning, !session.isFinished else { return }
        session.start()
        isRunning = true
        lastUpdate = nil
    }

    /// Freezes the scene completely (SpriteView's own pause is not reliable).
    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        isPaused = suspended
        lastUpdate = nil
        touchStart = nil
    }

    func dash() {
        guard isRunning, !isSuspended else { return }
        handle(session.dash())
    }

    func switchRail() {
        guard isRunning, !isSuspended else { return }
        lastSwitchFrom = session.cart.rail
        handle(session.requestSwitch())
    }

    // MARK: - Building

    private func buildWorld() {
        sky.zPosition = -100
        addChild(sky)
        volcano.anchorPoint = CGPoint(x: 0.5, y: 1)
        volcano.zPosition = -90
        addChild(volcano)
        craterGlow.zPosition = -85
        craterGlow.blendMode = .add
        craterGlow.alpha = 0.5
        craterGlow.color = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
        craterGlow.colorBlendFactor = 1
        addChild(craterGlow)
        craterGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 1.4), .fadeAlpha(to: 0.55, duration: 1.4)])), withKey: "idle")

        for rail in Rail.allCases {
            let terrace = SKSpriteNode(imageNamed: "terrace")
            terrace.anchorPoint = CGPoint(x: 0.5, y: 1)
            terrace.centerRect = CGRect(x: 0.3, y: 0, width: 0.4, height: 1)
            terrace.zPosition = rail == .upper ? -60 : -40
            addChild(terrace)
            terraceNodes[rail] = terrace

            let track = SKSpriteNode(imageNamed: "rail_track")
            track.centerRect = CGRect(x: 0.2, y: 0, width: 0.6, height: 1)
            track.zPosition = rail == .upper ? -55 : -35
            addChild(track)
            railNodes[rail] = track

            let station = SKSpriteNode(imageNamed: "mine_entrance")
            station.zPosition = rail == .upper ? -54 : -34
            station.xScale = rail == .upper ? -1 : 1
            addChild(station)
            stationNodes[rail] = station
        }

        cartHeat.size = CGSize(width: 150, height: 110)
        cartHeat.blendMode = .add
        cartHeat.color = SKColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
        cartHeat.colorBlendFactor = 1
        cartHeat.alpha = 0
        cart.addChild(cartHeat)
        cartRider.texture = SKTexture(imageNamed: session.loadout.keeper.portraitArt)
        cartRider.size = CGSize(width: 46, height: 46)
        cartRider.position = CGPoint(x: -14, y: 36)
        cart.addChild(cartRider)
        cartCargo.size = CGSize(width: 66, height: 30)
        cartCargo.position = CGPoint(x: 6, y: 26)
        cartCargo.isHidden = true
        cart.addChild(cartCargo)
        cartBody.size = CGSize(width: 86, height: 58)
        cartBody.position = CGPoint(x: 0, y: 22)
        cart.addChild(cartBody)
        cart.zPosition = 20
        addChild(cart)

        ashShade.anchorPoint = CGPoint(x: 0.5, y: 0)
        ashShade.zPosition = 50
        ashShade.alpha = 0
        addChild(ashShade)
        ashCloud.zPosition = 51
        ashCloud.alpha = 0
        addChild(ashCloud)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutWorld()
    }

    private func layoutWorld() {
        guard size.width > 0, size.height > 0 else { return }
        let width = size.width, height = size.height
        halfTrack = min(width * 0.36, 330)
        lowerY = height * 0.24
        upperY = height * 0.44
        craterPoint = CGPoint(x: 0, y: height * 0.80)

        let skySize = sky.texture?.size() ?? CGSize(width: 1, height: 2)
        let skyScale = max(width / skySize.width, height / skySize.height)
        sky.size = CGSize(width: skySize.width * skyScale, height: skySize.height * skyScale)
        sky.position = CGPoint(x: 0, y: height / 2)

        // The crater sits at the top centre of the volcano artwork.
        let volcanoSize = volcano.texture?.size() ?? CGSize(width: 3, height: 2)
        let volcanoWidth = max(width * 1.25, 520)
        volcano.size = CGSize(width: volcanoWidth, height: volcanoWidth * volcanoSize.height / volcanoSize.width)
        volcano.position = CGPoint(x: 0, y: craterPoint.y + volcano.size.height * 0.035)
        craterGlow.size = CGSize(width: volcanoWidth * 0.5, height: volcanoWidth * 0.32)
        craterGlow.position = craterPoint

        for rail in Rail.allCases {
            let y = railY(rail)
            terraceNodes[rail]?.size = CGSize(width: halfTrack * 2 + 140, height: rail == .upper ? upperY - lowerY + 10 : lowerY + 10)
            terraceNodes[rail]?.position = CGPoint(x: 0, y: y - 4)
            railNodes[rail]?.size = CGSize(width: halfTrack * 2 + 60, height: 22)
            railNodes[rail]?.position = CGPoint(x: 0, y: y)
            let side = CGFloat(RunSession.bankSide(of: rail))
            // Keep the mine entrance fully on screen at the rail's end.
            stationNodes[rail]?.size = CGSize(width: 76, height: 72)
            stationNodes[rail]?.position = CGPoint(x: side * min(halfTrack + 30, width / 2 - 40), y: y + 30)
        }

        ashShade.size = CGSize(width: width, height: height)
        ashShade.position = .zero
        ashCloud.size = CGSize(width: width * 1.3, height: height * 0.45)
        ashCloud.position = CGPoint(x: 0, y: height * 0.86)
        syncCart()
    }

    private func railY(_ rail: Rail) -> CGFloat { rail == .upper ? upperY : lowerY }
    private func screenX(_ x: Double) -> CGFloat { CGFloat(x) * halfTrack }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Touches during the countdown or pause must not move the cart.
        guard isRunning, !isSuspended, !autopilot, let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchStart = (point, touch.timestamp)
        touchMovedFar = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStart, let touch = touches.first else { return }
        let point = touch.location(in: self)
        let dx = point.x - start.point.x, dy = point.y - start.point.y
        if hypot(dx, dy) > 14 { touchMovedFar = true }
        // Horizontal drags steer; a mostly vertical swipe is kept for switching rails.
        if abs(dx) >= abs(dy) * 0.6 {
            session.steer(to: Double(point.x / halfTrack))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStart, let touch = touches.first else { return }
        touchStart = nil
        let point = touch.location(in: self)
        let dx = point.x - start.point.x, dy = point.y - start.point.y
        if !touchMovedFar, touch.timestamp - start.time < 0.3 {
            dash()
        } else if abs(dy) > 40, abs(dy) > abs(dx) * 1.2 {
            let wanted: Rail = dy > 0 ? .upper : .lower
            if wanted != session.cart.rail { switchRail() }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isSuspended else { return }
        defer { lastUpdate = currentTime }
        guard let lastUpdate else { return }
        let dt = min(max(currentTime - lastUpdate, 0), 1.0 / 20)

        if isRunning {
            if autopilot { applyAutopilot() }
            handle(session.advance(by: dt))
        }
        syncCart()
        syncProjectiles()
        syncBoulders()
        syncLightning()
        syncAsh()

        hudAccumulator += dt
        if hudAccumulator >= 0.1 {
            hudAccumulator = 0
            gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
        }
    }

    private func applyAutopilot() {
        let decision = Autopilot.decide(session)
        session.steer(to: decision.targetX)
        if decision.switchRail { switchRail() }
        if decision.dash { dash() }
    }

    // MARK: - Sync visuals with the session

    private func syncCart() {
        let state = session.cart
        var y = railY(state.rail)
        if let target = state.switchingTo {
            let t = CGFloat(1 - state.switchRemaining / session.loadout.switchTime)
            y = railY(state.rail) + (railY(target) - railY(state.rail)) * t + sin(t * .pi) * 40
        }
        cart.position = CGPoint(x: screenX(state.x), y: y)
        cart.zPosition = (state.switchingTo ?? state.rail) == .upper ? -50 : 20
        cartBody.zRotation = CGFloat(state.targetX - state.x) * -0.25
        cartHeat.alpha = CGFloat(session.heatFraction) * 0.8
        cartBody.color = .red
        cartBody.colorBlendFactor = CGFloat(max(0, session.heatFraction - 0.5)) * 0.8
        cartCargo.isHidden = session.cargoCount == 0
        cartCargo.setScale(0.6 + min(0.6, CGFloat(session.cargoCount) * 0.06))
        cart.alpha = state.invulnerable > 0 ? (Int(session.elapsed * 12).isMultiple(of: 2) ? 0.45 : 1) : 1
    }

    private func syncProjectiles() {
        let live = Set(session.projectiles.map(\.id))
        for (id, node) in projectileNodes where !live.contains(id) {
            node.removeFromParent()
            projectileNodes[id] = nil
            shadowNodes.removeValue(forKey: id)?.removeFromParent()
        }
        let visibility = CGFloat(session.shadowVisibility)
        for projectile in session.projectiles {
            let node = projectileNodes[projectile.id] ?? makeProjectileNode(projectile)
            let shadow = shadowNodes[projectile.id] ?? makeShadowNode(projectile)
            let p = CGFloat(projectile.progress(at: session.elapsed))
            let end = CGPoint(x: screenX(projectile.x), y: railY(projectile.rail) + 14)
            let arc = (craterPoint.y - end.y) * 0.45 + 60
            node.position = CGPoint(
                x: craterPoint.x + (end.x - craterPoint.x) * p,
                y: craterPoint.y + (end.y - craterPoint.y) * p + arc * 4 * p * (1 - p)
            )
            node.zRotation += projectile.payload.isBomb ? 0.08 : 0.15
            shadow.setScale(0.35 + 0.65 * p)
            shadow.alpha = (0.2 + 0.6 * p) * visibility
        }
    }

    private func makeProjectileNode(_ projectile: Projectile) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: projectile.payload.art)
        let side: CGFloat = projectile.payload.isBomb ? 34 : projectile.payload == .core ? 32 : 26
        node.size = CGSize(width: side, height: side)
        node.zPosition = 30
        addChild(node)
        projectileNodes[projectile.id] = node
        if projectile.payload.isBomb || projectile.payload == .core {
            let trail = SKSpriteNode(imageNamed: "fx_glow")
            trail.size = CGSize(width: side * 2.2, height: side * 2.2)
            trail.blendMode = .add
            trail.color = projectile.payload.isBomb ? .orange : SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
            trail.colorBlendFactor = 1
            trail.alpha = 0.55
            trail.zPosition = -1
            node.addChild(trail)
        }
        return node
    }

    private func makeShadowNode(_ projectile: Projectile) -> SKSpriteNode {
        let shadow = SKSpriteNode(imageNamed: "fx_glow")
        shadow.size = CGSize(width: 70, height: 22)
        shadow.color = projectile.payload.isBomb ? SKColor(red: 0.45, green: 0.02, blue: 0, alpha: 1) : .black
        shadow.colorBlendFactor = 1
        shadow.position = CGPoint(x: screenX(projectile.x), y: railY(projectile.rail) + 4)
        shadow.zPosition = projectile.rail == .upper ? -52 : -32
        addChild(shadow)
        shadowNodes[projectile.id] = shadow
        return shadow
    }

    private func syncBoulders() {
        let live = Set(session.boulders.map(\.id))
        for (id, node) in boulderNodes where !live.contains(id) {
            node.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 1.3, duration: 0.25)]), .removeFromParent()]))
            boulderNodes[id] = nil
        }
        for boulder in session.boulders where boulderNodes[boulder.id] == nil {
            let node = SKSpriteNode(imageNamed: "boulder")
            node.size = CGSize(width: 50, height: 38)
            node.position = CGPoint(x: screenX(boulder.x), y: railY(boulder.rail) + 14)
            node.zPosition = boulder.rail == .upper ? -51 : 15
            node.setScale(0.3)
            node.run(.scale(to: 1, duration: 0.2))
            addChild(node)
            boulderNodes[boulder.id] = node
        }
    }

    private func syncLightning() {
        let live = Set(session.lightnings.map(\.id))
        for (id, node) in lightningNodes where !live.contains(id) {
            node.removeFromParent()
            lightningNodes[id] = nil
        }
        for bolt in session.lightnings where lightningNodes[bolt.id] == nil {
            let mark = SKSpriteNode(imageNamed: "fx_glow")
            mark.size = CGSize(width: 90, height: 34)
            mark.color = SKColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
            mark.colorBlendFactor = 1
            mark.blendMode = .add
            mark.position = CGPoint(x: screenX(bolt.x), y: railY(bolt.rail) + 6)
            mark.zPosition = 40
            mark.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)])))
            addChild(mark)
            lightningNodes[bolt.id] = mark
        }
    }

    private func syncAsh() {
        ashShade.alpha = CGFloat(session.ash) * 0.45
        ashCloud.alpha = CGFloat(min(1, session.ash * 1.3))
    }

    // MARK: - Event effects

    private func handle(_ events: [SessionEvent]) {
        for event in events {
            switch event {
            case .volleyWarning(let kind):
                flashCrater(kind)
            case .launched:
                craterBurst()
            case .caught(_, let value):
                popLabel("+\(value)", at: CGPoint(x: cart.position.x, y: cart.position.y + 70), color: SKColor(red: 1, green: 0.88, blue: 0.5, alpha: 1))
            case .missed(let projectile):
                burst(at: CGPoint(x: screenX(projectile.x), y: railY(projectile.rail) + 10), color: SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), count: 6)
            case .bombHit:
                burst(at: CGPoint(x: cart.position.x, y: cart.position.y + 30), color: .orange, count: 18)
                cart.run(.sequence([.moveBy(x: -8, y: 0, duration: 0.04), .moveBy(x: 16, y: 0, duration: 0.06), .moveBy(x: -8, y: 0, duration: 0.04)]))
            case .boulderFormed(let boulder):
                burst(at: CGPoint(x: screenX(boulder.x), y: railY(boulder.rail) + 14), color: SKColor(red: 1, green: 0.45, blue: 0.1, alpha: 1), count: 12)
            case .boulderBroken(let boulder, let gold, let byLightning):
                let point = CGPoint(x: screenX(boulder.x), y: railY(boulder.rail) + 16)
                burst(at: point, color: SKColor(red: 0.6, green: 0.5, blue: 0.9, alpha: 1), count: 14)
                popLabel((byLightning ? "ZAP +" : "SHARDS +") + "\(gold)", at: CGPoint(x: point.x, y: point.y + 40), color: SKColor(red: 0.8, green: 0.75, blue: 1, alpha: 1))
            case .banked(let gold, _, let multiplier):
                popLabel("BANKED +\(gold)  x\(Formatters.twoDecimalsTrimmed(multiplier))", at: CGPoint(x: cart.position.x - CGFloat(RunSession.bankSide(of: session.cart.rail)) * 60, y: cart.position.y + 90),
                         color: SKColor(red: 1, green: 0.9, blue: 0.55, alpha: 1), size: 20)
                steam(at: cart.position)
            case .overheated:
                steam(at: cart.position)
                popLabel("OVERHEAT!", at: CGPoint(x: cart.position.x, y: cart.position.y + 80), color: .orange, size: 20)
            case .lightningCaught(let bolt, let gold):
                strike(at: CGPoint(x: screenX(bolt.x), y: railY(bolt.rail)))
                popLabel("STORM +\(gold)", at: CGPoint(x: cart.position.x, y: cart.position.y + 80), color: SKColor(red: 0.6, green: 0.9, blue: 1, alpha: 1))
            case .lightningMissed(let bolt):
                strike(at: CGPoint(x: screenX(bolt.x), y: railY(bolt.rail)))
            case .finished:
                finishRun()
            case .blocked, .boulderCrumbled, .switchStarted, .switchFinished, .dashed, .lightningWarning:
                break
            }
            gameDelegate?.scene(self, didRegister: event)
        }
    }

    private func flashCrater(_ kind: VolleyKind) {
        craterGlow.removeAction(forKey: "warn")
        let gold = SKColor(red: 1, green: 0.82, blue: 0.3, alpha: 1)
        let red = SKColor(red: 1, green: 0.18, blue: 0.08, alpha: 1)
        let pulse: SKAction
        switch kind {
        case .coins:
            pulse = .sequence([.colorize(with: gold, colorBlendFactor: 1, duration: 0.1), .fadeAlpha(to: 1, duration: 0.25), .fadeAlpha(to: 0.6, duration: 0.25)])
        case .bombs:
            pulse = .sequence([.colorize(with: red, colorBlendFactor: 1, duration: 0.1), .fadeAlpha(to: 1, duration: 0.25), .fadeAlpha(to: 0.6, duration: 0.25)])
        case .mixed:
            pulse = .sequence([.colorize(with: gold, colorBlendFactor: 1, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12),
                               .colorize(with: red, colorBlendFactor: 1, duration: 0.12), .fadeAlpha(to: 0.7, duration: 0.12)])
        }
        craterGlow.run(.repeat(pulse, count: 3), withKey: "warn")
    }

    private func craterBurst() {
        craterGlow.removeAction(forKey: "warn")
        craterGlow.run(.sequence([.fadeAlpha(to: 1, duration: 0.05), .colorize(with: SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1), colorBlendFactor: 1, duration: 0.4), .fadeAlpha(to: 0.5, duration: 0.5)]))
        burst(at: craterPoint, color: SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), count: 16, spread: 70)
    }

    private func finishRun() {
        isRunning = false
        touchStart = nil
        for node in projectileNodes.values { node.removeFromParent() }
        for node in shadowNodes.values { node.removeFromParent() }
        projectileNodes.removeAll()
        shadowNodes.removeAll()
        cart.run(.fadeAlpha(to: 0.5, duration: 0.6))
        let summary = session.summary
        run(.sequence([.wait(forDuration: 1.1), .run { [weak self] in
            guard let self else { return }
            self.gameDelegate?.scene(self, didFinishWith: summary)
        }]))
    }

    private func burst(at point: CGPoint, color: SKColor, count: Int, spread: CGFloat = 36) {
        for index in 0..<count {
            let dot = SKSpriteNode(imageNamed: "fx_glow")
            dot.size = CGSize(width: 14, height: 14)
            dot.color = color
            dot.colorBlendFactor = 1
            dot.blendMode = .add
            dot.position = point
            dot.zPosition = 60
            addChild(dot)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + 0.4
            let distance = spread * (0.6 + CGFloat((index * 7) % 5) / 10)
            dot.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance + 14, duration: 0.45), .fadeOut(withDuration: 0.45), .scale(to: 0.3, duration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }

    private func steam(at point: CGPoint) {
        for index in 0..<8 {
            let puff = SKSpriteNode(imageNamed: "fx_glow")
            puff.size = CGSize(width: 40, height: 40)
            puff.color = .white
            puff.colorBlendFactor = 1
            puff.alpha = 0.7
            puff.position = CGPoint(x: point.x + CGFloat(index * 9 - 36), y: point.y + 40)
            puff.zPosition = 61
            addChild(puff)
            puff.run(.sequence([
                .group([.moveBy(x: CGFloat(index % 3 - 1) * 12, y: 70, duration: 0.9), .scale(to: 2, duration: 0.9), .fadeOut(withDuration: 0.9)]),
                .removeFromParent()
            ]))
        }
    }

    private func strike(at point: CGPoint) {
        let bolt = SKSpriteNode(imageNamed: "lightning_bolt")
        let height = max(80, size.height * 0.88 - point.y)
        bolt.size = CGSize(width: 54, height: height)
        bolt.anchorPoint = CGPoint(x: 0.5, y: 0)
        bolt.position = point
        bolt.zPosition = 62
        bolt.blendMode = .add
        addChild(bolt)
        bolt.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.06), .fadeAlpha(to: 1, duration: 0.06), .fadeOut(withDuration: 0.35), .removeFromParent()]))
        burst(at: point, color: SKColor(red: 0.6, green: 0.9, blue: 1, alpha: 1), count: 10)
    }

    private func popLabel(_ text: String, at point: CGPoint, color: SKColor, size: CGFloat = 17) {
        let label = SKLabelNode(fontNamed: "Rockwell-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.position = point
        label.zPosition = 70
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 44, duration: 0.9), .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent()
        ]))
    }
}
