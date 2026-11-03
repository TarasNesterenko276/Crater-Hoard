import SpriteKit

/// Receives everything the scene learns while a shift is running.
@MainActor
protocol HoardSceneDelegate: AnyObject {
    func scene(_ scene: HoardScene, didUpdate hud: GameHUDState)
    func scene(_ scene: HoardScene, didRegister event: SessionEvent)
    func scene(_ scene: HoardScene, didFinishWith summary: RunSummary)
    func sceneDidDropCoin(_ scene: HoardScene, canWeld: Bool)
}

/// Renders the crater shaft, the fulcrum beam, the claw and every coin, and runs the physics.
/// All scoring and rules live in `RunSession`; this class only reports what happened physically.
final class HoardScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: HoardSceneDelegate?
    private(set) var session: RunSession
    private let autopilot: Bool

    private enum Category {
        static let beam: UInt32 = 1 << 0
        static let piece: UInt32 = 1 << 1
    }

    private enum Layout {
        /// Claw height above the top of the hoard.
        static let clawGap: CGFloat = 230
        /// Space kept between the top of the view and the claw for the HUD.
        static let topMargin: CGFloat = 190
        static let notchHeight: CGFloat = 30
        static let lavaGapBelowBeam: CGFloat = 26
        static let clawReach: CGFloat = CGFloat(Balance.beamWidth) / 2 + 60
        static let heldOffset: CGFloat = -34
    }

    // Nodes
    private let cameraNode = SKCameraNode()
    private let backdrop = SKSpriteNode(imageNamed: "bg_shaft")
    private let beam = SKSpriteNode(imageNamed: "beam")
    private let fulcrum = SKSpriteNode(imageNamed: "fulcrum")
    private let pivotAnchor = SKNode()
    private let claw = SKNode()
    private let clawSprite = SKSpriteNode(imageNamed: "claw")
    private let chain = SKSpriteNode(imageNamed: "chain")
    private let heldCoin = SKSpriteNode()
    private let heldGlow = SKSpriteNode(imageNamed: "fx_glow")
    private let heatTrack = SKShapeNode(rectOf: CGSize(width: 70, height: 8), cornerRadius: 4)
    private let heatBand = SKShapeNode()
    private let heatFill = SKSpriteNode(color: .white, size: CGSize(width: 66, height: 4))
    private let lava = SKNode()
    private let lavaBody = SKSpriteNode(color: SKColor(red: 0.85, green: 0.25, blue: 0.08, alpha: 1), size: CGSize(width: 2_400, height: 1_400))
    private let lavaCrust = SKSpriteNode(imageNamed: "lava_crust")
    private let lavaGlow = SKSpriteNode(imageNamed: "fx_glow")

    private var pieceNodes: [Int: SKSpriteNode] = [:]
    private var pendingWelds: [(Int, Int)] = []
    private var pendingMints: [MintResult] = []
    private var pendingSpills: Set<Int> = []

    // State
    private var isRunning = false
    private var isSuspended = false
    private var lastUpdate: TimeInterval?
    private var hudAccumulator: TimeInterval = 0
    private var clawX: CGFloat = 0
    private var targetX: CGFloat = 0
    private var clawY: CGFloat = Layout.clawGap
    private var displayedTilt: Double = 0
    private var stackTop: CGFloat = 0
    private var touchIsActive = false
    private var landingCount = 0
    private var cameraFloor: CGFloat = 0
    private var isBeamPinned = false
    /// How many coins the autopilot stacks before it lets the lava win.
    static let autopilotLandings = 14

    init(size: CGSize, loadout: Loadout, seed: UInt64, autopilot: Bool) {
        session = RunSession(loadout: loadout, seed: seed)
        self.autopilot = autopilot
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.09, green: 0.07, blue: 0.08, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -11)
        physicsWorld.contactDelegate = self
        buildWorld()
        pinBeamIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public control

    func startRun() {
        guard !isRunning, !session.isFinished else { return }
        isRunning = true
        lastUpdate = nil
        handle(session.start())
    }

    /// Freezes the scene completely (SpriteView's own pause is not reliable for physics).
    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        isPaused = suspended
        physicsWorld.speed = suspended ? 0 : 1
        lastUpdate = nil
        touchIsActive = false
    }

    /// Lets go of the held coin from a button or the autopilot.
    func dropHeldCoin() {
        guard isRunning, !isSuspended, let ticket = session.release() else { return }
        let metal = ticket.metal
        let node = makePieceNode(id: ticket.id, kind: .coin(metal))
        node.position = convert(heldCoin.position, from: claw)
        node.zRotation = 0
        if ticket.canWeld {
            node.color = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            node.colorBlendFactor = CGFloat(ticket.heat) * 0.55
            node.run(.colorize(withColorBlendFactor: 0, duration: 1.2))
        }
        addChild(node)
        node.physicsBody?.velocity = CGVector(dx: 0, dy: -80)
        heldCoin.isHidden = true
        heldGlow.isHidden = true
        heatTrack.isHidden = true
        clawSprite.run(.sequence([.scaleX(to: 1.15, duration: 0.08), .scaleX(to: 1, duration: 0.2)]))
        gameDelegate?.sceneDidDropCoin(self, canWeld: ticket.canWeld)
    }

    // MARK: - Building

    private func buildWorld() {
        addChild(cameraNode)
        camera = cameraNode
        backdrop.zPosition = -100
        cameraNode.addChild(backdrop)

        // Lava pit: a deep body with a glowing crust on top.
        lava.zPosition = 30
        lavaBody.anchorPoint = CGPoint(x: 0.5, y: 1)
        lava.addChild(lavaBody)
        lavaCrust.anchorPoint = CGPoint(x: 0.5, y: 0.75)
        lavaCrust.size = CGSize(width: 1_200, height: 60)
        lava.addChild(lavaCrust)
        lavaGlow.size = CGSize(width: 1_100, height: 260)
        lavaGlow.alpha = 0.55
        lavaGlow.blendMode = .add
        lavaGlow.position = CGPoint(x: 0, y: 30)
        lava.addChild(lavaGlow)
        lavaCrust.run(.repeatForever(.sequence([
            .moveBy(x: 24, y: 0, duration: 2.4),
            .moveBy(x: -24, y: 0, duration: 2.4)
        ])))
        lavaGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 1.3), .fadeAlpha(to: 0.6, duration: 1.3)])))
        lava.position = CGPoint(x: 0, y: lavaSurfaceY(level: 0))
        addChild(lava)

        // Fulcrum rock and the beam pinned on top of it.
        fulcrum.size = CGSize(width: 150, height: 160)
        fulcrum.anchorPoint = CGPoint(x: 0.5, y: 1)
        fulcrum.position = CGPoint(x: 0, y: -CGFloat(Balance.beamThickness) + 6)
        fulcrum.zPosition = 5
        addChild(fulcrum)

        pivotAnchor.position = CGPoint(x: 0, y: -CGFloat(Balance.beamThickness) / 2)
        let anchorBody = SKPhysicsBody(circleOfRadius: 4)
        anchorBody.isDynamic = false
        anchorBody.categoryBitMask = 0
        anchorBody.collisionBitMask = 0
        pivotAnchor.physicsBody = anchorBody
        addChild(pivotAnchor)

        beam.size = CGSize(width: Balance.beamWidth, height: Balance.beamThickness + 14)
        beam.position = pivotAnchor.position
        beam.zPosition = 10
        beam.name = "beam"
        let beamBody = SKPhysicsBody(rectangleOf: CGSize(width: Balance.beamWidth, height: Balance.beamThickness))
        beamBody.density = 40
        beamBody.friction = 0.9
        beamBody.restitution = 0
        beamBody.angularDamping = 4
        beamBody.categoryBitMask = Category.beam
        beamBody.collisionBitMask = Category.piece
        beamBody.contactTestBitMask = Category.piece
        beam.physicsBody = beamBody
        addChild(beam)

        // The claw hangs on a long chain from the crater mouth.
        claw.zPosition = 40
        chain.anchorPoint = CGPoint(x: 0.5, y: 0)
        chain.size = CGSize(width: 18, height: 900)
        chain.position = CGPoint(x: 0, y: 18)
        claw.addChild(chain)
        clawSprite.size = CGSize(width: 96, height: 64)
        clawSprite.position = CGPoint(x: 0, y: -4)
        claw.addChild(clawSprite)
        heldGlow.size = CGSize(width: 170, height: 120)
        heldGlow.blendMode = .add
        heldGlow.position = CGPoint(x: 0, y: Layout.heldOffset)
        claw.addChild(heldGlow)
        heldCoin.position = CGPoint(x: 0, y: Layout.heldOffset)
        heldCoin.isHidden = true
        heldGlow.isHidden = true
        claw.addChild(heldCoin)

        heatTrack.fillColor = SKColor(white: 0, alpha: 0.55)
        heatTrack.strokeColor = SKColor(white: 1, alpha: 0.55)
        heatTrack.lineWidth = 1
        heatTrack.position = CGPoint(x: 0, y: 36)
        heatBand.fillColor = SKColor(red: 1, green: 0.82, blue: 0.35, alpha: 0.45)
        heatBand.strokeColor = .clear
        heatTrack.addChild(heatBand)
        heatFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        heatFill.position = CGPoint(x: -33, y: 0)
        heatTrack.addChild(heatFill)
        heatTrack.isHidden = true
        claw.addChild(heatTrack)
        layoutHeatBand()

        claw.position = CGPoint(x: 0, y: clawY)
        addChild(claw)
    }

    private func layoutHeatBand() {
        let weldWidth = 66 * CGFloat(session.loadout.weldFraction)
        heatBand.path = CGPath(rect: CGRect(x: 33 - weldWidth, y: -4, width: weldWidth, height: 8), transform: nil)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        pinBeamIfNeeded()
    }

    /// Pins the beam's centre to the fulcrum so it can only rotate, within the tilt limits.
    private func pinBeamIfNeeded() {
        guard !isBeamPinned, let beamBody = beam.physicsBody, let anchorBody = pivotAnchor.physicsBody else { return }
        isBeamPinned = true
        beam.position = pivotAnchor.position
        beam.zRotation = 0
        beamBody.velocity = .zero
        beamBody.angularVelocity = 0
        let pin = SKPhysicsJointPin.joint(withBodyA: anchorBody, bodyB: beamBody, anchor: pivotAnchor.position)
        pin.shouldEnableLimits = true
        pin.lowerAngleLimit = -CGFloat(Balance.maxTilt)
        pin.upperAngleLimit = CGFloat(Balance.maxTilt)
        pin.frictionTorque = 0
        physicsWorld.add(pin)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        let scale = max(430 / size.width, 820 / size.height)
        cameraNode.setScale(scale)
        // Backdrop is a camera child, so it is sized in view points.
        let texture = backdrop.texture?.size() ?? CGSize(width: 1, height: 2)
        let fill = max(size.width / texture.width, size.height / texture.height)
        backdrop.size = CGSize(width: texture.width * fill, height: texture.height * fill)
        cameraFloor = clawY - visibleHeight / 2 + Layout.topMargin
        cameraNode.position = CGPoint(x: 0, y: max(cameraFloor, cameraNode.position.y))
    }

    private var visibleHeight: CGFloat { size.height * cameraNode.yScale }

    private func lavaSurfaceY(level: Int) -> CGFloat {
        let deckBottom = -CGFloat(Balance.beamThickness) - Layout.lavaGapBelowBeam
        return deckBottom - CGFloat(session.lavaCapacity - level) * Layout.notchHeight
    }

    private func makePieceNode(id: Int, kind: PieceKind) -> SKSpriteNode {
        let size = CGSize(width: kind.width, height: kind.thickness)
        let node = SKSpriteNode(imageNamed: kind.art)
        node.size = CGSize(width: size.width + 6, height: size.height + 6)
        node.name = "p\(id)"
        node.zPosition = 20
        let body = SKPhysicsBody(rectangleOf: size)
        body.density = CGFloat(kind.weight)
        body.friction = 0.8
        body.restitution = 0.04
        body.linearDamping = 0.15
        body.angularDamping = 0.7
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = Category.piece
        body.collisionBitMask = Category.piece | Category.beam
        body.contactTestBitMask = Category.piece | Category.beam
        node.physicsBody = body
        pieceNodes[id] = node
        return node
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Touches during the countdown or pause must not move the claw.
        guard isRunning, !isSuspended, !autopilot, let touch = touches.first else { return }
        touchIsActive = true
        targetX = clampX(touch.location(in: self).x)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchIsActive, let touch = touches.first else { return }
        targetX = clampX(touch.location(in: self).x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchIsActive else { return }
        touchIsActive = false
        if let touch = touches.first { targetX = clampX(touch.location(in: self).x) }
        // Snap the claw so the coin falls where the finger was lifted.
        clawX = targetX
        claw.position.x = clawX
        dropHeldCoin()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchIsActive = false
    }

    private func clampX(_ x: CGFloat) -> CGFloat {
        min(Layout.clawReach, max(-Layout.clawReach, x))
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isSuspended else { return }
        defer { lastUpdate = currentTime }
        guard let lastUpdate else { return }
        let dt = min(max(currentTime - lastUpdate, 0), 1.0 / 20)

        if isRunning {
            handle(session.advance(by: dt))
            if autopilot { steerAutopilot() }
        }
        clawX += (targetX - clawX) * min(1, CGFloat(dt) * 14)
        claw.position.x = clawX
        updateBeam(dt: dt)
        measureHoard()
        followCamera(dt: dt)
        updateHeldCoin()
        detectSpills()

        hudAccumulator += dt
        if hudAccumulator >= 0.1 {
            hudAccumulator = 0
            gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
        }
    }

    override func didSimulatePhysics() {
        applyPendingMints()
        applyPendingWelds()
    }

    private func updateBeam(dt: TimeInterval) {
        let loads: [(weight: Double, offset: Double)] = session.pieces.values.compactMap { piece in
            guard piece.hasLanded, let node = pieceNodes[piece.id], node.position.y > -40 else { return nil }
            return (piece.kind.weight, Double(node.position.x))
        }
        let target = RunSession.tiltTarget(loads: loads, restoringFactor: session.loadout.restoringFactor)
        displayedTilt += (target - displayedTilt) * min(1, dt * 1.6)
        // Drive the pinned beam towards the rule-computed angle. Positive tilt dips the right end.
        let current = -Double(beam.zRotation)
        beam.physicsBody?.angularVelocity = CGFloat(-(displayedTilt - current) * 6)
        if isRunning {
            handle(session.updateTilt(current))
        }
    }

    private func measureHoard() {
        var top: CGFloat = 0
        for piece in session.pieces.values where piece.hasLanded {
            guard let node = pieceNodes[piece.id], let body = node.physicsBody,
                  abs(body.velocity.dy) < 60, node.position.y > -30 else { continue }
            top = max(top, node.position.y + CGFloat(piece.kind.thickness) / 2)
        }
        stackTop += (top - stackTop) * 0.1
        session.updateHeight(points: Double(top))
    }

    private func followCamera(dt: TimeInterval) {
        let desiredClawY = max(stackTop, 0) + Layout.clawGap
        clawY += (desiredClawY - clawY) * min(1, CGFloat(dt) * 2.5)
        claw.position.y = clawY
        let desiredCamera = max(cameraFloor, clawY - visibleHeight / 2 + Layout.topMargin)
        cameraNode.position.y += (desiredCamera - cameraNode.position.y) * min(1, CGFloat(dt) * 3)
    }

    private func updateHeldCoin() {
        guard let held = session.held else { return }
        let heat = CGFloat(held.heat)
        heldCoin.colorBlendFactor = heat * 0.6
        heldGlow.alpha = 0.25 + heat * 0.75
        heldGlow.setScale(0.7 + heat * 0.5)
        heatFill.size.width = max(0.5, 66 * heat)
        heatFill.color = session.heldIsWeldHot
            ? SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
            : SKColor(red: 0.55, green: 0.85, blue: 0.8, alpha: 1)
    }

    private func detectSpills() {
        let lavaTop = lava.position.y
        for (id, node) in pieceNodes where !pendingSpills.contains(id) {
            if node.position.y < lavaTop + 4 || abs(node.position.x) > 900 {
                pendingSpills.insert(id)
                sink(node)
                handle(session.spill(id))
            }
        }
    }

    private func steerAutopilot() {
        guard session.held != nil else { return }
        let topPiece = session.pieces.values
            .filter(\.hasLanded)
            .compactMap { piece in pieceNodes[piece.id].map { (piece, $0) } }
            .max { $0.1.position.y < $1.1.position.y }
        let base = topPiece.map { $0.1.position.x } ?? 0
        if landingCount >= Self.autopilotLandings {
            // After a demo stack, the autopilot tips coins into the lava so the shift ends on its own.
            targetX = Layout.clawReach
        } else {
            // Lean against the tilt so the beam returns to level.
            targetX = clampX(base - CGFloat(displayedTilt) * 320)
        }
        let aligned = abs(clawX - targetX) < 3
        let heat = session.held?.heat ?? 0
        if aligned, heat >= session.weldThreshold + 0.03 || heat < 0.2 {
            dropHeldCoin()
        }
    }

    // MARK: - Physics contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard isRunning, let a = contact.bodyA.node, let b = contact.bodyB.node else { return }
        resolveLanding(of: a, against: b)
        resolveLanding(of: b, against: a)
    }

    private func resolveLanding(of node: SKNode, against other: SKNode) {
        guard let id = pieceID(of: node), let piece = session.pieces[id], !piece.hasLanded else { return }
        let support: Support
        if other.name == "beam" {
            support = .beam
        } else if let otherID = pieceID(of: other), session.pieces[otherID]?.hasLanded == true {
            support = .piece(otherID)
        } else {
            return
        }
        let events = session.land(id, on: support)
        for event in events {
            if case .landed(_, let welded, _) = event, welded, case .piece(let below) = support {
                pendingWelds.append((id, below))
            }
            if case .minted(let mint) = event {
                pendingMints.append(mint)
            }
        }
        handle(events)
    }

    private func pieceID(of node: SKNode) -> Int? {
        guard let name = node.name, name.hasPrefix("p") else { return nil }
        return Int(name.dropFirst())
    }

    private func applyPendingWelds() {
        guard !pendingWelds.isEmpty else { return }
        for (topID, bottomID) in pendingWelds {
            guard let top = pieceNodes[topID], let bottom = pieceNodes[bottomID],
                  let topBody = top.physicsBody, let bottomBody = bottom.physicsBody else { continue }
            let anchor = CGPoint(x: (top.position.x + bottom.position.x) / 2, y: (top.position.y + bottom.position.y) / 2)
            physicsWorld.add(SKPhysicsJointFixed.joint(withBodyA: topBody, bodyB: bottomBody, anchor: anchor))
            spark(at: anchor, color: SKColor(red: 1, green: 0.8, blue: 0.4, alpha: 1))
        }
        pendingWelds.removeAll()
    }

    private func applyPendingMints() {
        guard !pendingMints.isEmpty else { return }
        for mint in pendingMints {
            guard let bottom = pieceNodes[mint.consumed[0]] else { continue }
            let position = bottom.position
            let rotation = bottom.zRotation
            for id in mint.consumed {
                pieceNodes.removeValue(forKey: id)?.removeFromParent()
            }
            let ingot = makePieceNode(id: mint.ingotID, kind: .ingot(mint.metal))
            let lift = CGFloat(Balance.ingotThickness - mint.metal.thickness) / 2
            ingot.position = CGPoint(x: position.x, y: position.y + lift)
            ingot.zRotation = rotation
            ingot.setScale(0.6)
            addChild(ingot)
            ingot.run(.scale(to: 1, duration: 0.25))
            if mint.isWelded, case .piece(let supportID) = mint.support,
               let below = pieceNodes[supportID], let body = ingot.physicsBody, let belowBody = below.physicsBody {
                physicsWorld.add(SKPhysicsJointFixed.joint(withBodyA: body, bodyB: belowBody, anchor: ingot.position))
            }
            spark(at: ingot.position, color: SKColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), count: 18)
            popLabel("MINT +\(mint.bonus)", at: CGPoint(x: ingot.position.x, y: ingot.position.y + 30), color: SKColor(red: 1, green: 0.86, blue: 0.45, alpha: 1))
        }
        pendingMints.removeAll()
    }

    // MARK: - Event handling

    private func handle(_ events: [SessionEvent]) {
        for event in events {
            switch event {
            case .newCoin(_, let metal):
                heldCoin.texture = SKTexture(imageNamed: metal.coinArt)
                heldCoin.size = CGSize(width: metal.width + 6, height: metal.thickness + 6)
                heldCoin.color = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
                heldCoin.isHidden = false
                heldGlow.isHidden = false
                heatTrack.isHidden = false
                heldCoin.setScale(0.3)
                heldCoin.run(.scale(to: 1, duration: 0.18))
            case .autoDrop:
                dropHeldCoin()
                continue
            case .landed(let id, let welded, let gold):
                guard let node = pieceNodes[id] else { break }
                landingCount += 1
                popLabel(welded ? "WELD +\(gold)" : "+\(gold)", at: CGPoint(x: node.position.x, y: node.position.y + 24),
                         color: welded ? SKColor(red: 0.55, green: 0.92, blue: 0.84, alpha: 1) : SKColor(red: 1, green: 0.86, blue: 0.5, alpha: 1))
            case .lavaRose(let level), .lavaCooled(let level):
                lava.run(.moveTo(y: lavaSurfaceY(level: level), duration: 0.6), withKey: "lava")
            case .finished:
                finishRun()
            case .minted, .spilled, .steadyRaised, .steadyLost:
                break
            }
            gameDelegate?.scene(self, didRegister: event)
        }
    }

    private func finishRun() {
        isRunning = false
        touchIsActive = false
        heldCoin.isHidden = true
        heldGlow.isHidden = true
        heatTrack.isHidden = true
        claw.run(.moveBy(x: 0, y: 400, duration: 0.8))
        let summary = session.summary
        run(.sequence([.wait(forDuration: 1.1), .run { [weak self] in
            guard let self else { return }
            self.gameDelegate?.scene(self, didFinishWith: summary)
        }]))
    }

    // MARK: - Effects

    private func sink(_ node: SKSpriteNode) {
        node.physicsBody = nil
        node.run(.sequence([
            .group([.moveBy(x: 0, y: -40, duration: 0.6), .fadeOut(withDuration: 0.6), .colorize(with: .orange, colorBlendFactor: 1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let id = pieceID(of: node) { pieceNodes[id] = nil }
        spark(at: CGPoint(x: node.position.x, y: lava.position.y), color: SKColor(red: 1, green: 0.5, blue: 0.15, alpha: 1), count: 14)
    }

    private func spark(at point: CGPoint, color: SKColor, count: Int = 10) {
        for index in 0..<count {
            let dot = SKSpriteNode(imageNamed: "fx_glow")
            dot.size = CGSize(width: 14, height: 14)
            dot.color = color
            dot.colorBlendFactor = 1
            dot.blendMode = .add
            dot.position = point
            dot.zPosition = 60
            addChild(dot)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + 0.3
            let distance = CGFloat(30 + (index * 7) % 26)
            dot.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance + 12, duration: 0.45), .fadeOut(withDuration: 0.45), .scale(to: 0.3, duration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }

    private func popLabel(_ text: String, at point: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "Rockwell-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = color
        label.position = point
        label.zPosition = 70
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 46, duration: 0.9), .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent()
        ]))
    }
}
