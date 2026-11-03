import Testing
@testable import CraterHoard

/// Helpers that play a session the way the scene would.
extension RunSession {
    /// Releases the held coin immediately (hot) and lands it on `support`. Returns the coin id and the events.
    @discardableResult
    mutating func dropAndLand(on support: Support, coolFor seconds: Double = 0) -> (id: Int, events: [SessionEvent]) {
        if held == nil { _ = advance(by: 1) }
        if seconds > 0 { _ = advance(by: seconds) }
        guard let ticket = release() else { return (-1, []) }
        return (ticket.id, land(ticket.id, on: support))
    }
}

@MainActor
@Suite("Run session flow")
struct RunSessionFlowTests {
    @Test func startBringsTheFirstCoinIntoTheClaw() {
        var session = RunSession(loadout: .starter, seed: 7, scriptedMetals: [.silver, .gold])
        let events = session.start()
        #expect(events == [.newCoin(id: 1, metal: .silver)])
        #expect(session.held?.heat == 1)
        #expect(session.upcoming == .gold)
        #expect(session.start().isEmpty, "Starting twice must not spawn another coin")
    }

    @Test func coinsCoolAndTheClawLetsGoWhenCold() {
        var session = RunSession(loadout: .starter, seed: 1)
        _ = session.start()
        let duration = session.held?.coolDuration ?? 0
        _ = session.advance(by: duration / 2)
        #expect(abs((session.held?.heat ?? 0) - 0.5) < 0.001)
        let events = session.advance(by: duration)
        #expect(events == [.autoDrop])
        #expect(session.advance(by: 0.1).isEmpty, "Auto drop is requested only once")
    }

    @Test func releasingTriggersReloadAndANewCoin() {
        var session = RunSession(loadout: .starter, seed: 3)
        _ = session.start()
        #expect(session.release() != nil)
        #expect(session.held == nil)
        #expect(session.release() == nil, "Nothing left to release")
        #expect(session.advance(by: Balance.reloadDelay / 2).isEmpty)
        let events = session.advance(by: Balance.reloadDelay)
        #expect(events.count == 1)
        #expect(session.held != nil)
        #expect(session.coinsDropped == 1)
    }

    @Test func coinsCoolFasterAsTheShiftGoesOn() {
        var session = RunSession(loadout: .starter, seed: 9)
        _ = session.start()
        let first = session.currentCoolDuration
        for _ in 0..<30 { session.dropAndLand(on: .beam) }
        #expect(session.currentCoolDuration < first)
        #expect(session.currentCoolDuration >= Balance.minimumCoolDuration)
    }

    @Test func sameSeedGivesTheSameCoins() {
        func metals(seed: UInt64) -> [CoinMetal] {
            var session = RunSession(loadout: .starter, seed: seed)
            _ = session.start()
            var result: [CoinMetal] = []
            for _ in 0..<20 {
                if let held = session.held { result.append(held.metal) }
                session.dropAndLand(on: .beam)
            }
            return result
        }
        #expect(metals(seed: 42) == metals(seed: 42))
        #expect(metals(seed: 42) != metals(seed: 43))
    }

    @Test func summaryReflectsTheShift() {
        var session = RunSession(loadout: .starter, seed: 5, scriptedMetals: [.copper, .silver])
        _ = session.start()
        session.dropAndLand(on: .beam)
        session.updateHeight(points: 80)
        session.updateHeight(points: 40)
        let summary = session.summary
        #expect(summary.coinsLanded == 1)
        #expect(summary.heightCentimetres == 40, "Peak height is kept")
        #expect(summary.score == summary.gold + 40)
        #expect(summary.keeperID == Keeper.pip.rawValue)
    }
}

@MainActor
@Suite("Mechanic: weld heat")
struct WeldTests {
    @Test func hotCoinsWeldToTheCoinBelow() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.copper, .silver])
        _ = session.start()
        let base = session.dropAndLand(on: .beam)
        let top = session.dropAndLand(on: .piece(base.id))
        #expect(top.events.contains(.landed(id: top.id, welded: true, gold: 12)), "8 × steady 1.5 (Pip starts at 1.25)")
        #expect(session.welds == 1)
        #expect(session.pieces[top.id]?.isWelded == true)
    }

    @Test func coinsNeverWeldToTheBeam() {
        var session = RunSession(loadout: .starter, seed: 1)
        _ = session.start()
        let drop = session.dropAndLand(on: .beam)
        #expect(session.pieces[drop.id]?.isWelded == false)
        #expect(session.welds == 0)
    }

    @Test func cooledCoinsDoNotWeld() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.copper, .silver])
        _ = session.start()
        let base = session.dropAndLand(on: .beam)
        let cool = (session.currentCoolDuration) * 0.8
        let top = session.dropAndLand(on: .piece(base.id), coolFor: cool)
        #expect(session.pieces[top.id]?.isWelded == false)
    }

    @Test func bellowsWidenTheWeldWindow() {
        var loadout = Loadout.starter
        let narrow = RunSession(loadout: loadout, seed: 1).weldThreshold
        loadout.bellows = 5
        let wide = RunSession(loadout: loadout, seed: 1).weldThreshold
        #expect(wide < narrow)
        #expect(loadout.weldFraction == 0.6)
    }

    @Test func cinderKeepsCoinsHotLonger() {
        let pip = RunSession(loadout: .starter, seed: 1).currentCoolDuration
        let cinder = RunSession(loadout: Loadout(keeper: .cinder), seed: 1).currentCoolDuration
        #expect(cinder > pip)
    }
}

@MainActor
@Suite("Mechanic: minting")
struct MintTests {
    @Test func threeStackedCoinsOfOneMetalMintAnIngot() throws {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.gold, .gold, .gold, .copper])
        _ = session.start()
        let a = session.dropAndLand(on: .beam)
        let b = session.dropAndLand(on: .piece(a.id))
        let c = session.dropAndLand(on: .piece(b.id))
        let mint = try #require(c.events.compactMap { event -> MintResult? in
            if case .minted(let result) = event { return result }
            return nil
        }.first)
        #expect(mint.consumed == [a.id, b.id, c.id])
        #expect(mint.metal == .gold)
        #expect(mint.support == .beam)
        #expect(session.pieces[a.id] == nil && session.pieces[b.id] == nil && session.pieces[c.id] == nil)
        #expect(session.pieces[mint.ingotID]?.kind == .ingot(.gold))
        #expect(session.mints == 1)
        #expect(mint.bonus > 0)
    }

    @Test func mixedMetalsDoNotMint() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.gold, .silver, .gold])
        _ = session.start()
        let a = session.dropAndLand(on: .beam)
        let b = session.dropAndLand(on: .piece(a.id))
        let c = session.dropAndLand(on: .piece(b.id))
        #expect(!c.events.contains { if case .minted = $0 { true } else { false } })
        #expect(session.mints == 0)
    }

    @Test func coinsSideBySideDoNotMint() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.copper, .copper, .copper])
        _ = session.start()
        let a = session.dropAndLand(on: .beam)
        session.dropAndLand(on: .beam)
        let c = session.dropAndLand(on: .piece(a.id))
        #expect(!c.events.contains { if case .minted = $0 { true } else { false } })
    }

    @Test func obsidianNeverMints() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.obsidian, .obsidian, .obsidian])
        _ = session.start()
        let a = session.dropAndLand(on: .beam)
        let b = session.dropAndLand(on: .piece(a.id))
        session.dropAndLand(on: .piece(b.id))
        #expect(session.mints == 0)
    }

    @Test func mintingCoolsTheLava() {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.silver, .copper, .copper, .copper, .copper])
        _ = session.start()
        let spilled = session.dropAndLand(on: .beam)
        _ = session.spill(spilled.id)
        #expect(session.lavaLevel == 1)
        let a = session.dropAndLand(on: .beam)
        let b = session.dropAndLand(on: .piece(a.id))
        let c = session.dropAndLand(on: .piece(b.id))
        #expect(c.events.contains(.lavaCooled(level: 0)))
        #expect(session.lavaLevel == 0)
    }

    @Test func emberPaysMoreForMints() {
        func bonus(_ keeper: Keeper) -> Int {
            var session = RunSession(loadout: Loadout(keeper: keeper), seed: 1, scriptedMetals: [.gold, .gold, .gold])
            _ = session.start()
            let a = session.dropAndLand(on: .beam)
            let b = session.dropAndLand(on: .piece(a.id))
            let c = session.dropAndLand(on: .piece(b.id))
            return c.events.compactMap { if case .minted(let m) = $0 { m.bonus } else { nil } }.first ?? 0
        }
        #expect(bonus(.ember) > bonus(.cinder))
    }

    @Test func piecesOnAMintedCoinNowRestOnTheIngot() throws {
        var session = RunSession(loadout: .starter, seed: 1, scriptedMetals: [.copper, .copper, .silver, .copper])
        _ = session.start()
        let a = session.dropAndLand(on: .beam)
        let b = session.dropAndLand(on: .piece(a.id))
        let side = session.dropAndLand(on: .piece(b.id))
        let c = session.dropAndLand(on: .piece(b.id))
        let ingotID = try #require(c.events.compactMap { if case .minted(let m) = $0 { m.ingotID } else { nil } }.first)
        #expect(session.pieces[side.id]?.support == .piece(ingotID))
    }
}

@MainActor
@Suite("Mechanic: fulcrum")
struct FulcrumTests {
    @Test func weightOffCentreTipsTheBeamTowardsIt() {
        let right = RunSession.tiltTarget(loads: [(1, 100)], restoringFactor: 1)
        let left = RunSession.tiltTarget(loads: [(1, -100)], restoringFactor: 1)
        #expect(right > 0)
        #expect(left == -right)
        #expect(RunSession.tiltTarget(loads: [(1, 50), (1, -50)], restoringFactor: 1) == 0)
    }

    @Test func tiltIsClampedAndReducedByCounterweight() {
        let heavy = RunSession.tiltTarget(loads: [(50, 140)], restoringFactor: 1)
        #expect(heavy == Balance.maxTilt)
        var loadout = Loadout.starter
        loadout.counterweight = 5
        let base = RunSession.tiltTarget(loads: [(1, 100)], restoringFactor: 1)
        let stiff = RunSession.tiltTarget(loads: [(1, 100)], restoringFactor: loadout.restoringFactor)
        #expect(stiff < base)
        #expect(Loadout(keeper: .basalt).restoringFactor > Loadout.starter.restoringFactor)
    }

    @Test func steadyLandingsRaiseTheMultiplierUpToTheCap() {
        var session = RunSession(loadout: Loadout(keeper: .cinder), seed: 2)
        _ = session.start()
        #expect(session.multiplier == 1)
        session.dropAndLand(on: .beam)
        #expect(session.multiplier == 1.25)
        for _ in 0..<10 { session.dropAndLand(on: .beam) }
        #expect(session.multiplier == session.loadout.multiplierCap)
        #expect(session.bestMultiplier == session.loadout.multiplierCap)
    }

    @Test func tippingOutOfTheSteadyZoneResetsTheMultiplier() {
        var session = RunSession(loadout: .starter, seed: 2)
        _ = session.start()
        session.dropAndLand(on: .beam)
        #expect(session.multiplier > 1)
        #expect(session.updateTilt(0.01).isEmpty, "Small tilt stays steady")
        #expect(session.updateTilt(0.2) == [.steadyLost])
        #expect(session.multiplier == 1)
        #expect(session.updateTilt(0.25).isEmpty, "Already reset")
    }

    @Test func landingsWhileTippedDoNotRaiseTheMultiplier() {
        var session = RunSession(loadout: Loadout(keeper: .ash), seed: 2)
        _ = session.start()
        _ = session.updateTilt(0.25)
        session.dropAndLand(on: .beam)
        #expect(session.multiplier == 1)
    }

    @Test func multiplierScalesGold() {
        var session = RunSession(loadout: Loadout(keeper: .ash), seed: 2, scriptedMetals: [.gold, .gold, .silver])
        _ = session.start()
        let first = session.dropAndLand(on: .beam)
        let second = session.dropAndLand(on: .beam)
        #expect(first.events.contains(.landed(id: first.id, welded: false, gold: 15)))
        #expect(second.events.contains(.landed(id: second.id, welded: false, gold: 19)), "15 × 1.25 rounded")
    }
}

@MainActor
@Suite("Mechanic: lava creep")
struct LavaTests {
    @Test func spillsRaiseTheLavaAndCostTheirGold() {
        var session = RunSession(loadout: .starter, seed: 4, scriptedMetals: [.gold, .copper])
        _ = session.start()
        let drop = session.dropAndLand(on: .beam)
        let goldBefore = session.gold
        let events = session.spill(drop.id)
        #expect(events.contains(.lavaRose(level: 1)))
        #expect(session.gold == 0)
        #expect(goldBefore > 0)
        #expect(session.spills == 1)
    }

    @Test func coinsThatMissEverythingStillRaiseTheLava() {
        var session = RunSession(loadout: .starter, seed: 4)
        _ = session.start()
        let ticket = session.release()
        let events = session.spill(ticket?.id ?? -1)
        #expect(events.contains(.spilled(id: ticket?.id ?? -1, lostGold: 0)))
        #expect(session.lavaLevel == 1)
    }

    @Test func lavaReachingTheBeamEndsTheShift() {
        var session = RunSession(loadout: .starter, seed: 4)
        _ = session.start()
        var finished = false
        for _ in 0..<session.lavaCapacity {
            let drop = session.dropAndLand(on: .beam)
            finished = session.spill(drop.id).contains(.finished)
        }
        #expect(finished)
        #expect(session.isFinished)
        #expect(session.release() == nil)
        #expect(session.advance(by: 1).isEmpty)
    }

    @Test func spillingTheBaseLeavesPiecesAboveUnsupported() {
        var session = RunSession(loadout: .starter, seed: 4, scriptedMetals: [.copper, .silver])
        _ = session.start()
        let base = session.dropAndLand(on: .beam)
        let top = session.dropAndLand(on: .piece(base.id))
        _ = session.spill(base.id)
        #expect(session.pieces[top.id]?.support == nil)
    }

    @Test func hermitLosesOnlyHalfAndAshHasAnExtraNotch() {
        var session = RunSession(loadout: Loadout(keeper: .hermit), seed: 4, scriptedMetals: [.obsidian, .copper])
        _ = session.start()
        let drop = session.dropAndLand(on: .beam)
        let credited = session.gold
        _ = session.spill(drop.id)
        #expect(session.gold == credited - credited / 2)
        #expect(Loadout(keeper: .ash).lavaNotches == Loadout.starter.lavaNotches + 1)
    }

    @Test func lavaSinkAddsNotches() {
        var loadout = Loadout.starter
        #expect(loadout.lavaNotches == 4)
        loadout.lavaSink = 1
        #expect(loadout.lavaNotches == 5)
        loadout.lavaSink = 5
        #expect(loadout.lavaNotches == 7)
    }
}
