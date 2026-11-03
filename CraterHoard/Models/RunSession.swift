import Foundation

/// The cart on the slope.
struct CartState: Equatable, Sendable {
    var x: Double = 0
    var rail: Rail = .lower
    /// Where the player is steering to.
    var targetX: Double = 0
    /// Set while jumping to the other rail.
    var switchingTo: Rail?
    var switchRemaining: Double = 0
    var dashRemaining: Double = 0
    var dashCooldown: Double = 0
    var invulnerable: Double = 0

    var isSwitching: Bool { switchingTo != nil }
    var isDashing: Bool { dashRemaining > 0 }
}

/// Discrete things the rules decided, for the scene and the HUD to react to.
enum SessionEvent: Equatable, Sendable {
    case volleyWarning(VolleyKind)
    case launched([Projectile])
    case caught(Projectile, value: Int)
    case missed(Projectile)
    case bombHit(Projectile, cargoLost: Int)
    case boulderFormed(Boulder)
    case boulderBroken(Boulder, gold: Int, byLightning: Bool)
    case boulderCrumbled(Boulder)
    case blocked(Boulder)
    case banked(gold: Int, coins: Int, multiplier: Double)
    case overheated(cargoLost: Int)
    case switchStarted(Rail)
    case switchFinished(Rail)
    case dashed
    case lightningWarning(Lightning)
    case lightningCaught(Lightning, gold: Int)
    case lightningMissed(Lightning)
    case finished
}

/// Pure rules of one shift on the volcano's slope: volleys, the cart, heat, boulders,
/// rails and the ash cloud. The SpriteKit scene only draws this state and forwards input.
struct RunSession: Sendable {
    enum Phase: Equatable, Sendable {
        case waiting
        case running
        case finished
    }

    let loadout: Loadout
    private var rng: SeededGenerator
    /// When false, volleys and lightning only happen through `launch` and `scheduleLightning` (tests).
    private let autoEvents: Bool

    private(set) var phase: Phase = .waiting
    private(set) var elapsed: TimeInterval = 0
    private(set) var cart = CartState()
    private(set) var planks: Int
    private(set) var heat: Double = 0
    private(set) var cargoCount = 0
    private(set) var cargoValue = 0
    /// Extra bank multiplier from lightning caught since the last bank.
    private(set) var charge: Double = 0
    private(set) var gold = 0
    private(set) var ash: Double = 0

    private(set) var projectiles: [Projectile] = []
    private(set) var boulders: [Boulder] = []
    private(set) var lightnings: [Lightning] = []
    private(set) var warning: (kind: VolleyKind, firesAt: TimeInterval)?
    private var nextVolleyAt: TimeInterval = Balance.firstVolleyDelay
    private var nextLightningAt: TimeInterval = 0
    private var nextID = 1
    private var blockedBoulderID: Int?

    // Statistics
    private(set) var coinsCaught = 0
    private(set) var coresCaught = 0
    private(set) var banks = 0
    private(set) var bestBank = 0
    private(set) var bouldersBroken = 0
    private(set) var lightningCaught = 0
    private(set) var volleys = 0

    init(loadout: Loadout, seed: UInt64, autoEvents: Bool = true) {
        self.loadout = loadout
        self.autoEvents = autoEvents
        rng = SeededGenerator(seed: seed)
        planks = loadout.planks
    }

    // MARK: - Derived

    var isFinished: Bool { phase == .finished }
    var score: Int { gold + Int(elapsed) * 2 }
    var heatFraction: Double { min(1, heat / loadout.heatCapacity) }

    /// Multiplier the current cargo would bank at.
    var cargoMultiplier: Double {
        guard cargoCount > 0 else { return 1 }
        return min(Balance.cargoMultiplierCap, 1 + Balance.cargoStep * Double(cargoCount - 1)) + charge
    }

    /// How clearly landing shadows show through the ash, `0.25...1`.
    var shadowVisibility: Double {
        guard !loadout.seesThroughAsh else { return 1 }
        return 1 - 0.75 * max(0, (ash - 0.3) / 0.7)
    }

    var isAshStorm: Bool { ash >= Balance.lightningThreshold }

    /// Which end of the cart's rail has the mine entrance: -1 left (lower), +1 right (upper).
    static func bankSide(of rail: Rail) -> Double { rail == .lower ? -1 : 1 }

    func isInBankZone(x: Double, rail: Rail) -> Bool {
        rail == .lower ? x <= -loadout.bankZone : x >= loadout.bankZone
    }

    var summary: RunSummary {
        RunSummary(
            score: score,
            gold: gold,
            duration: elapsed,
            coinsCaught: coinsCaught,
            coresCaught: coresCaught,
            banks: banks,
            bestBank: bestBank,
            bouldersBroken: bouldersBroken,
            lightningCaught: lightningCaught,
            volleys: volleys,
            keeperID: loadout.keeper.rawValue
        )
    }

    // MARK: - Input

    mutating func start() {
        guard phase == .waiting else { return }
        phase = .running
    }

    /// Steers the cart towards a position on the rail.
    mutating func steer(to x: Double) {
        cart.targetX = min(Balance.trackLimit, max(-Balance.trackLimit, x))
    }

    /// Jumps to the other rail. The cart cannot catch anything while switching.
    mutating func requestSwitch() -> [SessionEvent] {
        guard phase == .running, !cart.isSwitching else { return [] }
        let target = cart.rail.other
        cart.switchingTo = target
        cart.switchRemaining = loadout.switchTime
        blockedBoulderID = nil
        return [.switchStarted(target)]
    }

    /// A short burst of speed that also breaks obsidian boulders.
    mutating func dash() -> [SessionEvent] {
        guard phase == .running, cart.dashCooldown <= 0 else { return [] }
        cart.dashRemaining = Balance.dashDuration
        cart.dashCooldown = Balance.dashCooldown
        return [.dashed]
    }

    // MARK: - Clock

    mutating func advance(by dt: TimeInterval) -> [SessionEvent] {
        guard phase == .running, dt > 0 else { return [] }
        elapsed += dt
        var events: [SessionEvent] = []

        tickCartTimers(dt, events: &events)
        moveCart(dt, events: &events)
        if autoEvents { scheduleVolleys(events: &events) }
        resolveLandings(events: &events)
        if autoEvents { scheduleAutoLightning(events: &events) }
        resolveLightning(events: &events)
        updateHeat(dt, events: &events)
        bankIfPossible(events: &events)
        crumbleBoulders(events: &events)
        ash = max(0, ash - Balance.ashClearingPerSecond * dt)
        return events
    }

    // MARK: - Spawning (also used directly by tests)

    /// Throws payloads at the slope. Returns the projectiles in the air.
    @discardableResult
    mutating func launch(_ items: [(payload: Payload, rail: Rail, x: Double)], flightTime: Double) -> [Projectile] {
        let launched = items.map { item in
            defer { nextID += 1 }
            return Projectile(
                id: nextID,
                payload: item.payload,
                rail: item.rail,
                x: min(Balance.trackLimit, max(-Balance.trackLimit, item.x)),
                launchedAt: elapsed,
                landsAt: elapsed + flightTime
            )
        }
        projectiles += launched
        for projectile in launched {
            ash += projectile.payload.isBomb ? Balance.ashPerBomb : Balance.ashPerProjectile
        }
        ash = min(1, ash)
        volleys += 1
        return launched
    }

    @discardableResult
    mutating func scheduleLightning(rail: Rail, x: Double) -> Lightning {
        let bolt = Lightning(id: nextID, rail: rail, x: x, strikesAt: elapsed + Balance.lightningWarning)
        nextID += 1
        lightnings.append(bolt)
        return bolt
    }

    @discardableResult
    mutating func placeBoulder(rail: Rail, x: Double) -> Boulder {
        let boulder = Boulder(id: nextID, rail: rail, x: x, formedAt: elapsed)
        nextID += 1
        boulders.append(boulder)
        return boulder
    }

    /// Sets the ash level directly (tests).
    mutating func setAsh(_ value: Double) {
        ash = min(1, max(0, value))
    }

    // MARK: - Private: cart

    private mutating func tickCartTimers(_ dt: TimeInterval, events: inout [SessionEvent]) {
        cart.dashRemaining = max(0, cart.dashRemaining - dt)
        cart.dashCooldown = max(0, cart.dashCooldown - dt)
        cart.invulnerable = max(0, cart.invulnerable - dt)
        if let target = cart.switchingTo {
            cart.switchRemaining -= dt
            if cart.switchRemaining <= 0 {
                cart.rail = target
                cart.switchingTo = nil
                cart.switchRemaining = 0
                events.append(.switchFinished(target))
            }
        }
    }

    private mutating func moveCart(_ dt: TimeInterval, events: inout [SessionEvent]) {
        let speed = loadout.cartSpeed * (cart.isDashing ? Balance.dashSpeedFactor : 1)
        let delta = min(speed * dt, max(-speed * dt, cart.targetX - cart.x))
        var newX = cart.x + delta
        guard !cart.isSwitching, delta != 0 else {
            cart.x = newX
            return
        }
        let reach = Balance.cartHalfWidth + Balance.boulderHalfWidth
        for boulder in boulders where boulder.rail == cart.rail {
            let edge = delta > 0 ? boulder.x - reach : boulder.x + reach
            let crosses = delta > 0 ? (cart.x <= edge + 0.0001 && newX > edge) : (cart.x >= edge - 0.0001 && newX < edge)
            guard crosses else { continue }
            if cart.isDashing || loadout.breaksBouldersOnContact {
                breakBoulder(boulder, byLightning: false, events: &events)
            } else {
                newX = edge
                if blockedBoulderID != boulder.id {
                    blockedBoulderID = boulder.id
                    events.append(.blocked(boulder))
                }
            }
        }
        cart.x = newX
    }

    // MARK: - Private: volleys

    private mutating func scheduleVolleys(events: inout [SessionEvent]) {
        if let pending = warning {
            guard elapsed >= pending.firesAt else { return }
            warning = nil
            let launched = launch(makeVolley(kind: pending.kind), flightTime: flightTime)
            events.append(.launched(launched))
            nextVolleyAt = elapsed + max(Balance.minimumVolleyInterval, Balance.baseVolleyInterval - 0.012 * elapsed)
        } else if elapsed >= nextVolleyAt {
            let kind = pickVolleyKind()
            warning = (kind, elapsed + Balance.warningDuration)
            events.append(.volleyWarning(kind))
        }
    }

    private var flightTime: Double {
        max(Balance.minimumFlightTime, Balance.baseFlightTime - 0.004 * elapsed) + rng.peekUnit() * 0.3
    }

    private mutating func pickVolleyKind() -> VolleyKind {
        let bombShare = min(0.55, 0.2 + 0.004 * elapsed)
        let roll = rng.unit()
        if roll < bombShare * 0.45 { return .bombs }
        if roll < bombShare * 1.6 { return .mixed }
        return .coins
    }

    private mutating func makeVolley(kind: VolleyKind) -> [(payload: Payload, rail: Rail, x: Double)] {
        let size = min(9, 3 + Int(elapsed / 18))
        return (0..<size).map { _ in
            let rail: Rail = rng.unit() < 0.5 ? .upper : .lower
            let x = -0.82 + rng.unit() * 1.64
            let payload: Payload
            switch kind {
            case .bombs:
                payload = .bomb
            case .coins:
                payload = coin(for: rail)
            case .mixed:
                payload = rng.unit() < (rail == .upper ? 0.5 : 0.3) ? .bomb : coin(for: rail)
            }
            return (payload, rail, x)
        }
    }

    private mutating func coin(for rail: Rail) -> Payload {
        let roll = rng.unit()
        switch rail {
        case .lower:
            return roll < 0.6 ? .coin(.copper) : roll < 0.9 ? .coin(.silver) : .coin(.gold)
        case .upper:
            if roll < 0.05 { return .core }
            return roll < 0.3 ? .coin(.copper) : roll < 0.68 ? .coin(.silver) : .coin(.gold)
        }
    }

    // MARK: - Private: landings

    private func cartIsOn(_ rail: Rail) -> Bool {
        !cart.isSwitching && cart.rail == rail
    }

    /// While switching the cart is exposed on both rails.
    private func cartIsExposed(on rail: Rail) -> Bool {
        cart.isSwitching || cart.rail == rail
    }

    private mutating func resolveLandings(events: inout [SessionEvent]) {
        let landed = projectiles.filter { $0.landsAt <= elapsed }
        guard !landed.isEmpty else { return }
        projectiles.removeAll { $0.landsAt <= elapsed }
        for projectile in landed where phase == .running {
            let near = abs(projectile.x - cart.x) <= Balance.catchRadius
            if projectile.payload.isBomb {
                if near, cartIsExposed(on: projectile.rail), cart.invulnerable <= 0 {
                    let lost = cargoCount - Int((Double(cargoCount) * loadout.cargoKeptOnHit).rounded(.down))
                    let keptValue = Int((Double(cargoValue) * loadout.cargoKeptOnHit).rounded(.down))
                    cargoCount -= lost
                    cargoValue = keptValue
                    if cargoCount == 0 { charge = 0 }
                    cart.invulnerable = Balance.hitInvulnerability
                    events.append(.bombHit(projectile, cargoLost: lost))
                    losePlank(events: &events)
                } else if !isInBankZone(x: projectile.x, rail: projectile.rail),
                          !boulders.contains(where: { $0.rail == projectile.rail && abs($0.x - projectile.x) < Balance.boulderHalfWidth * 2 }) {
                    let boulder = placeBoulder(rail: projectile.rail, x: projectile.x)
                    events.append(.boulderFormed(boulder))
                }
            } else if near, cartIsOn(projectile.rail) {
                let railFactor = projectile.rail == .upper ? Balance.upperRailValueFactor : 1
                let value = Int((Double(projectile.payload.value) * loadout.valueFactor * railFactor).rounded())
                cargoCount += 1
                cargoValue += value
                coinsCaught += 1
                if projectile.payload == .core { coresCaught += 1 }
                heat += projectile.payload.heat * (projectile.rail == .upper ? Balance.upperRailHeatFactor : 1) * loadout.heatFactor
                events.append(.caught(projectile, value: value))
            } else {
                events.append(.missed(projectile))
            }
        }
    }

    private mutating func losePlank(events: inout [SessionEvent]) {
        planks -= 1
        if planks <= 0 {
            planks = 0
            phase = .finished
            projectiles.removeAll()
            lightnings.removeAll()
            warning = nil
            events.append(.finished)
        }
    }

    // MARK: - Private: lightning

    private mutating func scheduleAutoLightning(events: inout [SessionEvent]) {
        guard isAshStorm, elapsed >= nextLightningAt else { return }
        nextLightningAt = elapsed + Balance.lightningInterval
        let rail: Rail = rng.unit() < 0.5 ? .upper : .lower
        let bolt = scheduleLightning(rail: rail, x: -0.8 + rng.unit() * 1.6)
        events.append(.lightningWarning(bolt))
    }

    private mutating func resolveLightning(events: inout [SessionEvent]) {
        let striking = lightnings.filter { $0.strikesAt <= elapsed }
        guard !striking.isEmpty else { return }
        lightnings.removeAll { $0.strikesAt <= elapsed }
        for bolt in striking where phase == .running {
            if cartIsOn(bolt.rail), abs(bolt.x - cart.x) <= Balance.lightningRadius {
                let bonus = Balance.lightningGold * loadout.lightningFactor
                gold += bonus
                charge = min(Balance.lightningChargeCap, charge + Balance.lightningCharge)
                lightningCaught += 1
                events.append(.lightningCaught(bolt, gold: bonus))
            } else if let boulder = boulders.first(where: { $0.rail == bolt.rail && abs($0.x - bolt.x) <= Balance.lightningRadius }) {
                breakBoulder(boulder, byLightning: true, events: &events)
            } else {
                events.append(.lightningMissed(bolt))
            }
        }
    }

    // MARK: - Private: heat, banking, crust

    private mutating func updateHeat(_ dt: TimeInterval, events: inout [SessionEvent]) {
        if cargoCount > 0 {
            let railFactor = cart.rail == .upper ? Balance.upperRailHeatFactor : 1
            heat += Double(cargoCount) * Balance.carryHeatPerCoin * railFactor * loadout.heatFactor * dt
        } else {
            heat = max(0, heat - Balance.coolingPerSecond * dt)
        }
        guard heat >= loadout.heatCapacity, phase == .running else { return }
        let lost = cargoCount
        cargoCount = 0
        cargoValue = 0
        charge = 0
        heat = loadout.heatCapacity * Balance.heatAfterOverheat
        events.append(.overheated(cargoLost: lost))
        losePlank(events: &events)
    }

    private mutating func bankIfPossible(events: inout [SessionEvent]) {
        guard phase == .running, cargoCount > 0, cartIsOn(cart.rail), isInBankZone(x: cart.x, rail: cart.rail) else { return }
        let multiplier = cargoMultiplier
        let banked = Int((Double(cargoValue) * multiplier).rounded())
        gold += banked
        banks += 1
        bestBank = max(bestBank, banked)
        events.append(.banked(gold: banked, coins: cargoCount, multiplier: multiplier))
        cargoCount = 0
        cargoValue = 0
        charge = 0
        heat = 0
    }

    private mutating func breakBoulder(_ boulder: Boulder, byLightning: Bool, events: inout [SessionEvent]) {
        guard boulders.contains(where: { $0.id == boulder.id }) else { return }
        boulders.removeAll { $0.id == boulder.id }
        gold += Balance.boulderShardGold
        bouldersBroken += 1
        if blockedBoulderID == boulder.id { blockedBoulderID = nil }
        events.append(.boulderBroken(boulder, gold: Balance.boulderShardGold, byLightning: byLightning))
    }

    private mutating func crumbleBoulders(events: inout [SessionEvent]) {
        let old = boulders.filter { elapsed - $0.formedAt >= Balance.boulderLifetime }
        guard !old.isEmpty else { return }
        boulders.removeAll { elapsed - $0.formedAt >= Balance.boulderLifetime }
        for boulder in old { events.append(.boulderCrumbled(boulder)) }
    }
}

private extension SeededGenerator {
    /// A value in `0..<1` derived from the current state without advancing it (stable flight jitter).
    func peekUnit() -> Double {
        var copy = self
        return copy.unit()
    }
}
