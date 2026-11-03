import Testing
@testable import CraterHoard

/// A session with no automatic volleys or lightning, so each test throws exactly what it needs.
private func manualSession(_ loadout: Loadout = .starter) -> RunSession {
    var session = RunSession(loadout: loadout, seed: 1, autoEvents: false)
    session.start()
    return session
}

extension RunSession {
    /// Advances in small steps, collecting every event.
    @discardableResult
    mutating func run(for seconds: Double, step: Double = 1.0 / 60) -> [SessionEvent] {
        var events: [SessionEvent] = []
        var left = seconds
        while left > 0.000_1 {
            events += advance(by: min(step, left))
            left -= step
        }
        return events
    }

    /// Puts the cart at `x` on `rail` immediately (via steering over time).
    mutating func park(at x: Double) {
        steer(to: x)
        run(for: 2)
    }
}

@MainActor
@Suite("Shift flow")
struct ShiftFlowTests {
    @Test func nothingHappensBeforeTheShiftStarts() {
        var session = RunSession(loadout: .starter, seed: 3)
        #expect(session.advance(by: 1).isEmpty)
        #expect(session.elapsed == 0)
        #expect(session.dash().isEmpty)
    }

    @Test func cartRollsTowardsTheFingerAtItsSpeed() {
        var session = manualSession()
        session.steer(to: 0.9)
        session.run(for: 0.2)
        #expect(abs(session.cart.x - Balance.baseCartSpeed * 0.2) < 0.02)
        session.run(for: 2)
        #expect(session.cart.x == 0.9)
        session.steer(to: 5)
        #expect(session.cart.targetX == Balance.trackLimit)
    }

    @Test func dashIsFasterAndHasACooldown() {
        var session = manualSession()
        session.steer(to: 0.9)
        #expect(session.dash() == [.dashed])
        #expect(session.dash().isEmpty, "Still cooling down")
        session.run(for: 0.2)
        #expect(session.cart.x > Balance.baseCartSpeed * 0.2 * 1.5)
        session.run(for: Balance.dashCooldown)
        #expect(session.dash() == [.dashed])
    }

    @Test func sameSeedPlaysTheSameShift() {
        func launched(_ seed: UInt64) -> [Projectile] {
            var session = RunSession(loadout: .starter, seed: seed)
            session.start()
            return session.run(for: 20).flatMap { event -> [Projectile] in
                if case .launched(let projectiles) = event { return projectiles }
                return []
            }
        }
        #expect(!launched(9).isEmpty)
        #expect(launched(9) == launched(9))
        #expect(launched(9) != launched(10))
    }

    @Test func summaryReflectsTheShift() {
        var session = manualSession()
        session.launch([(.coin(.gold), .lower, 0)], flightTime: 0.5)
        session.run(for: 0.6)
        session.park(at: -0.95)
        let summary = session.summary
        #expect(summary.coinsCaught == 1)
        #expect(summary.banks == 1)
        #expect(summary.gold == 15)
        #expect(summary.score == summary.gold + Int(session.elapsed) * 2)
        #expect(summary.keeperID == "pip")
    }
}

@MainActor
@Suite("Mechanic: telegraphed volleys")
struct VolleyTests {
    @Test func everyVolleyIsAnnouncedBeforeItLaunches() {
        var session = RunSession(loadout: .starter, seed: 5)
        session.start()
        var warnedAt: Double?
        var launchedAt: Double?
        for _ in 0..<600 where launchedAt == nil {
            for event in session.advance(by: 1.0 / 60) {
                if case .volleyWarning = event { warnedAt = warnedAt ?? session.elapsed }
                if case .launched(let projectiles) = event {
                    launchedAt = session.elapsed
                    #expect(!projectiles.isEmpty)
                }
            }
        }
        #expect(warnedAt != nil && launchedAt != nil)
        #expect((launchedAt ?? 0) - (warnedAt ?? 0) >= Balance.warningDuration - 0.02)
    }

    @Test func coinVolleysCarryNoBombsAndBombVolleysOnlyBombs() {
        var session = RunSession(loadout: .starter, seed: 11)
        session.start()
        var checked = 0
        var pending: VolleyKind?
        for _ in 0..<(60 * 90) {
            for event in session.advance(by: 1.0 / 60) {
                if case .volleyWarning(let kind) = event { pending = kind }
                if case .launched(let projectiles) = event, let kind = pending {
                    switch kind {
                    case .coins: #expect(projectiles.allSatisfy { !$0.payload.isBomb })
                    case .bombs: #expect(projectiles.allSatisfy { $0.payload.isBomb })
                    case .mixed: break
                    }
                    checked += 1
                }
            }
        }
        #expect(checked > 10)
    }

    @Test func coresOnlyFlyToTheUpperRail() {
        var session = RunSession(loadout: .starter, seed: 21)
        session.start()
        var cores: [Projectile] = []
        for _ in 0..<(60 * 120) {
            for event in session.advance(by: 1.0 / 60) {
                if case .launched(let projectiles) = event { cores += projectiles.filter { $0.payload == .core } }
            }
        }
        #expect(cores.allSatisfy { $0.rail == .upper })
    }
}

@MainActor
@Suite("Mechanic: hot cargo")
struct CargoTests {
    @Test func catchingCoinsFillsTheCartAndHeatsIt() {
        var session = manualSession()
        session.launch([(.coin(.copper), .lower, 0.05)], flightTime: 0.5)
        let events = session.run(for: 0.6)
        #expect(events.contains { if case .caught(_, 4) = $0 { true } else { false } })
        #expect(session.cargoCount == 1)
        #expect(session.heat > 0)
    }

    @Test func coinsOutOfReachAreMissed() {
        var session = manualSession()
        session.launch([(.coin(.copper), .lower, 0.6)], flightTime: 0.3)
        let events = session.run(for: 0.4)
        #expect(events.contains { if case .missed = $0 { true } else { false } })
        #expect(session.cargoCount == 0)
    }

    @Test func bankingAtTheMinePaysTheMultiplierAndCoolsTheCart() {
        var session = manualSession()
        session.launch((0..<5).map { _ in (Payload.coin(.silver), Rail.lower, 0.0) }, flightTime: 0.3)
        session.run(for: 0.4)
        #expect(session.cargoCount == 5)
        #expect(abs(session.cargoMultiplier - 1.32) < 0.001)
        session.steer(to: -0.95)
        let events = session.run(for: 1)
        #expect(events.contains { if case .banked(53, 5, _) = $0 { true } else { false } }, "40 gold × 1.32")
        #expect(session.gold == 53)
        #expect(session.heat == 0)
        #expect(session.cargoCount == 0)
    }

    @Test func theUpperRailBanksAtTheOtherEnd() {
        let session = manualSession()
        #expect(session.isInBankZone(x: -0.9, rail: .lower))
        #expect(!session.isInBankZone(x: -0.9, rail: .upper))
        #expect(session.isInBankZone(x: 0.9, rail: .upper))
        #expect(Loadout(keeper: .pip).bankZone < Loadout(keeper: .cinder).bankZone)
    }

    @Test func overheatingMeltsTheCargoAndCostsAPlank() {
        var session = manualSession()
        session.launch((0..<12).map { _ in (Payload.coin(.gold), Rail.lower, 0.0) }, flightTime: 0.2)
        let events = session.run(for: 0.3)
        #expect(events.contains(.overheated(cargoLost: 12)))
        #expect(session.planks == Loadout.starter.planks - 1)
        #expect(session.heat < Loadout.starter.heatCapacity)
    }

    @Test func carryingKeepsHeatingUntilBanked() {
        var session = manualSession()
        session.launch([(.coin(.copper), .lower, 0)], flightTime: 0.2)
        session.run(for: 0.3)
        let before = session.heat
        session.run(for: 3)
        #expect(session.heat > before)
        let cinder = manualSession(Loadout(keeper: .cinder))
        #expect(cinder.loadout.heatFactor < 1)
    }

    @Test func aBombKnocksTheCargoOutAndCracksAPlank() {
        var session = manualSession()
        session.launch([(.coin(.gold), .lower, 0), (.coin(.gold), .lower, 0)], flightTime: 0.2)
        session.run(for: 0.3)
        session.launch([(.bomb, .lower, 0.05)], flightTime: 0.2)
        let events = session.run(for: 0.3)
        #expect(events.contains { if case .bombHit(_, 2) = $0 { true } else { false } })
        #expect(session.cargoCount == 0)
        #expect(session.planks == Loadout.starter.planks - 1)
        #expect(session.cart.invulnerable > 0)
    }

    @Test func hermitKeepsHalfTheCargo() {
        var session = manualSession(Loadout(keeper: .hermit))
        session.launch((0..<4).map { _ in (Payload.coin(.copper), Rail.lower, 0.0) }, flightTime: 0.2)
        session.run(for: 0.3)
        session.launch([(.bomb, .lower, 0)], flightTime: 0.2)
        session.run(for: 0.3)
        #expect(session.cargoCount == 2)
    }

    @Test func losingTheLastPlankEndsTheShift() {
        var session = manualSession()
        var finished = false
        for _ in 0..<session.loadout.planks {
            session.launch([(.bomb, .lower, session.cart.x)], flightTime: 0.2)
            finished = session.run(for: Balance.hitInvulnerability + 0.3).contains(.finished) || finished
        }
        #expect(finished)
        #expect(session.isFinished)
        #expect(session.advance(by: 1).isEmpty)
    }
}

@MainActor
@Suite("Mechanic: obsidian crust")
struct CrustTests {
    @Test func dodgedBombsHardenIntoBoulders() {
        var session = manualSession()
        session.launch([(.bomb, .lower, 0.5)], flightTime: 0.2)
        let events = session.run(for: 0.3)
        #expect(events.contains { if case .boulderFormed = $0 { true } else { false } })
        #expect(session.boulders.count == 1)
    }

    @Test func noBouldersFormAtTheMineEntrance() {
        var session = manualSession()
        session.launch([(.bomb, .lower, -0.93)], flightTime: 0.2)
        session.run(for: 0.3)
        #expect(session.boulders.isEmpty)
    }

    @Test func bouldersBlockTheCart() {
        var session = manualSession()
        let boulder = session.placeBoulder(rail: .lower, x: 0.5)
        session.steer(to: 0.9)
        let events = session.run(for: 1.5)
        #expect(events.contains(.blocked(boulder)))
        #expect(session.cart.x <= 0.5 - Balance.cartHalfWidth - Balance.boulderHalfWidth + 0.001)
    }

    @Test func dashingSmashesBouldersForShards() {
        var session = manualSession()
        session.placeBoulder(rail: .lower, x: 0.3)
        session.steer(to: 0.9)
        session.run(for: 0.05)
        _ = session.dash()
        let events = session.run(for: 0.5)
        #expect(events.contains { if case .boulderBroken(_, Balance.boulderShardGold, false) = $0 { true } else { false } })
        #expect(session.boulders.isEmpty)
        #expect(session.gold == Balance.boulderShardGold)
        #expect(session.bouldersBroken == 1)
    }

    @Test func basaltRollsThroughWithoutDashing() {
        var session = manualSession(Loadout(keeper: .basalt))
        session.placeBoulder(rail: .lower, x: 0.4)
        session.steer(to: 0.9)
        session.run(for: 1.5)
        #expect(session.boulders.isEmpty)
        #expect(session.cart.x == 0.9)
    }

    @Test func bouldersOnTheOtherRailDoNotBlock() {
        var session = manualSession()
        session.placeBoulder(rail: .upper, x: 0.3)
        session.steer(to: 0.9)
        session.run(for: 1.5)
        #expect(session.cart.x == 0.9)
    }

    @Test func bouldersCrumbleWithTime() {
        var session = manualSession()
        session.placeBoulder(rail: .lower, x: 0.5)
        let events = session.run(for: Balance.boulderLifetime + 0.1, step: 0.25)
        #expect(events.contains { if case .boulderCrumbled = $0 { true } else { false } })
        #expect(session.boulders.isEmpty)
    }
}

@MainActor
@Suite("Mechanic: two rails")
struct RailTests {
    @Test func switchingTakesTimeAndLandsOnTheOtherRail() {
        var session = manualSession()
        #expect(session.requestSwitch() == [.switchStarted(.upper)])
        #expect(session.requestSwitch().isEmpty, "Already switching")
        session.run(for: Balance.baseSwitchTime / 2)
        #expect(session.cart.isSwitching)
        let events = session.run(for: Balance.baseSwitchTime)
        #expect(events.contains(.switchFinished(.upper)))
        #expect(session.cart.rail == .upper)
    }

    @Test func theCartCannotCatchWhileSwitchingButCanBeHitOnEitherRail() {
        var session = manualSession()
        _ = session.requestSwitch()
        session.launch([(.coin(.gold), .lower, 0), (.bomb, .upper, 0)], flightTime: 0.1)
        let events = session.run(for: 0.15)
        #expect(events.contains { if case .missed = $0 { true } else { false } })
        #expect(events.contains { if case .bombHit = $0 { true } else { false } })
    }

    @Test func theUpperRailPaysMore() {
        var session = manualSession()
        _ = session.requestSwitch()
        session.run(for: 1)
        session.launch([(.coin(.copper), .upper, 0)], flightTime: 0.1)
        let events = session.run(for: 0.15)
        #expect(events.contains { if case .caught(_, 6) = $0 { true } else { false } }, "4 × 1.6 rounded")
    }

    @Test func railSwitchUpgradeShortensTheJump() {
        var loadout = Loadout.starter
        loadout.railSwitch = 5
        #expect(loadout.switchTime < Loadout.starter.switchTime)
        #expect(loadout.switchTime >= 0.2)
    }
}

@MainActor
@Suite("Mechanic: ash cloud")
struct AshTests {
    @Test func volleysThickenTheAshAndItClearsOverTime() {
        var session = manualSession()
        session.launch((0..<8).map { _ in (Payload.bomb, Rail.upper, 0.6) }, flightTime: 3)
        let thick = session.ash
        #expect(thick > 0.2)
        session.run(for: 2)
        #expect(session.ash < thick)
    }

    @Test func thickAshHidesShadowsUnlessAshIsAtTheCart() {
        var session = manualSession()
        session.setAsh(1)
        #expect(session.shadowVisibility == 0.25)
        session.setAsh(0.2)
        #expect(session.shadowVisibility == 1)
        var owl = manualSession(Loadout(keeper: .ash))
        owl.setAsh(1)
        #expect(owl.shadowVisibility == 1)
    }

    @Test func lightningUnderTheCartPaysAndChargesTheBank() {
        var session = manualSession()
        let bolt = session.scheduleLightning(rail: .lower, x: 0.05)
        let events = session.run(for: Balance.lightningWarning + 0.05)
        #expect(events.contains(.lightningCaught(bolt, gold: Balance.lightningGold)))
        #expect(session.gold == Balance.lightningGold)
        #expect(session.charge == Balance.lightningCharge)
    }

    @Test func emberDoublesLightning() {
        var session = manualSession(Loadout(keeper: .ember))
        let bolt = session.scheduleLightning(rail: .lower, x: 0)
        let events = session.run(for: 1)
        #expect(events.contains(.lightningCaught(bolt, gold: Balance.lightningGold * 2)))
    }

    @Test func lightningShattersBouldersItHits() {
        var session = manualSession()
        session.placeBoulder(rail: .upper, x: 0.5)
        session.scheduleLightning(rail: .upper, x: 0.5)
        let events = session.run(for: 1)
        #expect(events.contains { if case .boulderBroken(_, _, true) = $0 { true } else { false } })
    }

    @Test func ashStormsSparkLightningOnTheirOwn() {
        var session = RunSession(loadout: .starter, seed: 4)
        session.start()
        session.setAsh(1)
        let events = session.run(for: 1)
        #expect(events.contains { if case .lightningWarning = $0 { true } else { false } })
    }
}

@MainActor
@Suite("Autopilot")
struct AutopilotTests {
    @Test func runsTowardsCoinsAndAwayFromBombs() {
        var session = manualSession()
        session.launch([(.coin(.gold), .lower, 0.5)], flightTime: 2)
        #expect(Autopilot.decide(session).targetX == 0.5)
        session.launch([(.bomb, .lower, 0.05)], flightTime: 0.5)
        #expect(abs(Autopilot.decide(session).targetX - 0.05) > 0.3, "Dodges the bomb about to land")
    }

    @Test func goesToBankWhenFullOrHot() {
        var session = manualSession()
        session.launch((0..<5).map { _ in (Payload.coin(.copper), Rail.lower, 0.0) }, flightTime: 0.1)
        session.run(for: 0.2)
        #expect(Autopilot.decide(session).targetX == -Balance.trackLimit)
    }

    @Test func playsAWholeShiftToTheEnd() {
        var session = RunSession(loadout: .starter, seed: 77)
        session.start()
        for _ in 0..<(60 * 240) where !session.isFinished {
            let decision = Autopilot.decide(session, givesUpAfterBanks: 3)
            session.steer(to: decision.targetX)
            if decision.switchRail { _ = session.requestSwitch() }
            if decision.dash { _ = session.dash() }
            _ = session.advance(by: 1.0 / 60)
        }
        #expect(session.isFinished)
        #expect(session.banks >= 3)
        #expect(session.gold > 0)
    }
}
