import Foundation

/// What a piece rests on after it first lands.
enum Support: Equatable, Hashable, Sendable {
    case beam
    case piece(Int)
}

/// The rules' view of a coin or ingot that has left the claw.
struct Piece: Equatable, Sendable {
    let id: Int
    var kind: PieceKind
    /// Gold already credited for this piece (zero while it is still falling).
    var credited: Int
    /// `nil` while falling, or after whatever it rested on was lost.
    var support: Support?
    var isWelded: Bool
    var hasLanded: Bool
}

/// The coin currently glowing in the claw.
struct HeldCoin: Equatable, Sendable {
    let id: Int
    let metal: CoinMetal
    let coolDuration: Double
    var heldTime: Double = 0

    /// `1` straight out of the crater, `0` when fully cooled.
    var heat: Double { max(0, 1 - heldTime / coolDuration) }
}

/// Handed to the scene when a coin is released.
struct DropTicket: Equatable, Sendable {
    let id: Int
    let metal: CoinMetal
    /// Whether the coin was hot enough to weld to the coin it lands on.
    let canWeld: Bool
    let heat: Double
}

/// Three coins fused into one ingot.
struct MintResult: Equatable, Sendable {
    /// Consumed piece ids, from the bottom of the column to the top.
    let consumed: [Int]
    let ingotID: Int
    let metal: CoinMetal
    let bonus: Int
    /// The ingot inherits the bottom coin's resting place and weld.
    let support: Support?
    let isWelded: Bool
}

/// Discrete things the rules decided, for the scene and the HUD to react to.
enum SessionEvent: Equatable, Sendable {
    case newCoin(id: Int, metal: CoinMetal)
    case autoDrop
    case landed(id: Int, welded: Bool, gold: Int)
    case minted(MintResult)
    case spilled(id: Int, lostGold: Int)
    case lavaRose(level: Int)
    case lavaCooled(level: Int)
    case steadyRaised(Double)
    case steadyLost
    case finished
}

/// Pure rules of one shift at the crater. The SpriteKit scene does physics and drawing,
/// and reports landings, spills, tilt and height here. No framework dependencies, so it is fully testable.
struct RunSession: Sendable {
    enum Phase: Equatable, Sendable {
        case waiting
        case holding
        case reloading(remaining: Double)
        case finished
    }

    let loadout: Loadout
    private var rng: SeededGenerator

    private(set) var phase: Phase = .waiting
    private(set) var held: HeldCoin?
    /// Preview of the coin the claw brings next.
    private(set) var upcoming: CoinMetal
    private(set) var pieces: [Int: Piece] = [:]
    private var tickets: [Int: DropTicket] = [:]
    private var nextID = 1
    private var autoDropRequested = false
    private var lastMetal: CoinMetal?
    /// Metals handed out before random draws begin (deterministic tests).
    private var scriptedMetals: [CoinMetal]

    private(set) var elapsed: TimeInterval = 0
    private(set) var gold = 0
    private(set) var coinsDropped = 0
    private(set) var coinsLanded = 0
    private(set) var mints = 0
    private(set) var welds = 0
    private(set) var spills = 0
    private(set) var lavaLevel = 0
    private(set) var multiplier: Double
    private(set) var bestMultiplier: Double
    /// Beam tilt in radians; positive means the right end is lower.
    private(set) var tilt: Double = 0
    private(set) var heightCentimetres = 0
    private(set) var peakHeightCentimetres = 0

    init(loadout: Loadout, seed: UInt64, scriptedMetals: [CoinMetal] = []) {
        self.loadout = loadout
        self.scriptedMetals = scriptedMetals
        rng = SeededGenerator(seed: seed)
        multiplier = loadout.startingMultiplier
        bestMultiplier = loadout.startingMultiplier
        upcoming = .copper
        upcoming = drawMetal()
    }

    // MARK: - Derived

    var isFinished: Bool { phase == .finished }
    var lavaCapacity: Int { loadout.lavaNotches }
    var weldThreshold: Double { 1 - loadout.weldFraction }
    var steadyLimit: Double { loadout.steadyDegrees * .pi / 180 }
    var isSteady: Bool { abs(tilt) <= steadyLimit }
    var score: Int { gold + peakHeightCentimetres }

    /// Seconds the next coin takes to cool. Coins cool faster as the shift goes on.
    var currentCoolDuration: Double {
        let base = max(Balance.minimumCoolDuration, Balance.baseCoolDuration - Balance.coolSpeedupPerCoin * Double(coinsDropped))
        return base * loadout.coolFactor
    }

    var heldIsWeldHot: Bool {
        guard let held else { return false }
        return held.heat >= weldThreshold
    }

    var summary: RunSummary {
        RunSummary(
            score: score,
            gold: gold,
            heightCentimetres: peakHeightCentimetres,
            coinsLanded: coinsLanded,
            mints: mints,
            welds: welds,
            spills: spills,
            bestMultiplier: bestMultiplier,
            duration: elapsed,
            keeperID: loadout.keeper.rawValue
        )
    }

    // MARK: - Flow

    /// Brings the first coin into the claw.
    mutating func start() -> [SessionEvent] {
        guard phase == .waiting else { return [] }
        return [spawnCoin()]
    }

    /// Advances clocks: the held coin cools, and the claw reloads after a drop.
    mutating func advance(by dt: TimeInterval) -> [SessionEvent] {
        guard phase != .finished, phase != .waiting, dt > 0 else { return [] }
        elapsed += dt
        var events: [SessionEvent] = []
        switch phase {
        case .holding:
            held?.heldTime += dt
            if let held, held.heat <= 0, !autoDropRequested {
                autoDropRequested = true
                events.append(.autoDrop)
            }
        case .reloading(let remaining):
            let left = remaining - dt
            if left <= 0 {
                events.append(spawnCoin())
            } else {
                phase = .reloading(remaining: left)
            }
        case .waiting, .finished:
            break
        }
        return events
    }

    /// Lets go of the held coin. Returns `nil` when the claw is empty.
    mutating func release() -> DropTicket? {
        guard phase == .holding, let held else { return nil }
        let ticket = DropTicket(id: held.id, metal: held.metal, canWeld: held.heat >= weldThreshold, heat: held.heat)
        tickets[held.id] = ticket
        pieces[held.id] = Piece(id: held.id, kind: .coin(held.metal), credited: 0, support: nil, isWelded: false, hasLanded: false)
        self.held = nil
        coinsDropped += 1
        phase = .reloading(remaining: Balance.reloadDelay)
        return ticket
    }

    // MARK: - Reports from the scene

    /// A released coin touched the beam or another piece for the first time.
    mutating func land(_ id: Int, on support: Support) -> [SessionEvent] {
        guard phase != .finished, var piece = pieces[id], !piece.hasLanded else { return [] }
        if case .piece(let below) = support, pieces[below] == nil { return [] }

        let welds = tickets[id]?.canWeld == true && support != .beam
        let credited = Int((Double(piece.kind.metal.value) * multiplier).rounded())
        piece.hasLanded = true
        piece.support = support
        piece.isWelded = welds
        piece.credited = credited
        pieces[id] = piece
        tickets[id] = nil

        gold += credited
        coinsLanded += 1
        if welds { self.welds += 1 }

        var events: [SessionEvent] = [.landed(id: id, welded: welds, gold: credited)]
        if isSteady, multiplier < loadout.multiplierCap {
            multiplier = min(loadout.multiplierCap, multiplier + Balance.steadyStep)
            bestMultiplier = max(bestMultiplier, multiplier)
            events.append(.steadyRaised(multiplier))
        }
        if let mint = mintIfPossible(top: id) {
            events.append(.minted(mint))
            if lavaLevel > 0 {
                lavaLevel -= 1
                events.append(.lavaCooled(level: lavaLevel))
            }
        }
        return events
    }

    /// A piece fell into the lava (or out of the cave).
    mutating func spill(_ id: Int) -> [SessionEvent] {
        guard phase != .finished, let piece = pieces.removeValue(forKey: id) else { return [] }
        tickets[id] = nil
        let lost = min(gold, Int((Double(piece.credited) * loadout.spillPenalty).rounded()))
        gold -= lost
        spills += 1
        detachPieces(restingOn: id, reattachTo: nil)

        lavaLevel += 1
        var events: [SessionEvent] = [.spilled(id: id, lostGold: lost), .lavaRose(level: lavaLevel)]
        if lavaLevel >= lavaCapacity {
            phase = .finished
            held = nil
            events.append(.finished)
        }
        return events
    }

    /// Records the beam angle. Leaving the steady zone resets the multiplier.
    mutating func updateTilt(_ angle: Double) -> [SessionEvent] {
        tilt = angle
        guard phase != .finished, !isSteady, multiplier > 1 else { return [] }
        multiplier = 1
        return [.steadyLost]
    }

    /// Records the height of the hoard's highest resting point above the beam, in scene points.
    mutating func updateHeight(points: Double) {
        heightCentimetres = max(0, Int((points * Balance.centimetresPerPoint).rounded()))
        peakHeightCentimetres = max(peakHeightCentimetres, heightCentimetres)
    }

    // MARK: - Fulcrum physics helper

    /// The angle the beam settles at for the given loads (weight, horizontal offset from the pivot).
    /// Positive offsets are to the right; a positive result means the right end dips.
    static func tiltTarget(loads: [(weight: Double, offset: Double)], restoringFactor: Double) -> Double {
        let moment = loads.reduce(0) { $0 + $1.weight * $1.offset }
        let angle = moment / (Balance.baseRestoringMoment * restoringFactor)
        return min(Balance.maxTilt, max(-Balance.maxTilt, angle))
    }

    // MARK: - Private

    private mutating func spawnCoin() -> SessionEvent {
        let metal = upcoming
        upcoming = drawMetal()
        let coin = HeldCoin(id: nextID, metal: metal, coolDuration: currentCoolDuration)
        nextID += 1
        held = coin
        autoDropRequested = false
        phase = .holding
        return .newCoin(id: coin.id, metal: metal)
    }

    private mutating func drawMetal() -> CoinMetal {
        if !scriptedMetals.isEmpty {
            let metal = scriptedMetals.removeFirst()
            lastMetal = metal
            return metal
        }
        if let lastMetal, lastMetal.canMint, rng.unit() < Balance.veinChance {
            return lastMetal
        }
        let roll = rng.unit()
        let rare = loadout.rareChance
        let metal: CoinMetal
        if roll < rare * 0.3 {
            metal = .obsidian
        } else if roll < rare {
            metal = .gold
        } else if roll < rare + 0.33 {
            metal = .silver
        } else {
            metal = .copper
        }
        lastMetal = metal
        return metal
    }

    /// Three coins of one metal stacked directly on each other fuse into an ingot.
    private mutating func mintIfPossible(top id: Int) -> MintResult? {
        guard let top = pieces[id], case .coin(let metal) = top.kind, metal.canMint,
              case .piece(let middleID) = top.support, let middle = pieces[middleID], middle.kind == .coin(metal),
              case .piece(let bottomID) = middle.support, let bottom = pieces[bottomID], bottom.kind == .coin(metal)
        else { return nil }

        let consumedGold = top.credited + middle.credited + bottom.credited
        let bonus = Int((Double(consumedGold) * loadout.mintBonus).rounded())
        let ingotID = nextID
        nextID += 1

        for consumed in [bottomID, middleID, id] {
            pieces[consumed] = nil
        }
        pieces[ingotID] = Piece(
            id: ingotID,
            kind: .ingot(metal),
            credited: consumedGold + bonus,
            support: bottom.support,
            isWelded: bottom.isWelded,
            hasLanded: true
        )
        for consumed in [bottomID, middleID, id] {
            detachPieces(restingOn: consumed, reattachTo: ingotID)
        }
        gold += bonus
        mints += 1
        return MintResult(
            consumed: [bottomID, middleID, id],
            ingotID: ingotID,
            metal: metal,
            bonus: bonus,
            support: bottom.support,
            isWelded: bottom.isWelded
        )
    }

    private mutating func detachPieces(restingOn id: Int, reattachTo newID: Int?) {
        for (key, piece) in pieces where piece.support == .piece(id) {
            pieces[key]?.support = newID.map { .piece($0) }
        }
    }
}
