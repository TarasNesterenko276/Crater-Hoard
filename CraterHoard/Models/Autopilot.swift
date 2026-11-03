import Foundation

/// What the autopilot wants the cart to do this frame.
struct AutopilotDecision: Equatable, Sendable {
    var targetX: Double
    var switchRail = false
    var dash = false
}

/// Plays a shift by itself for UI tests and screenshot tours, which cannot react in real time.
/// After `givesUpAfterBanks` banks (or `givesUpAfter` seconds) it walks into bombs so the shift ends on its own.
enum Autopilot {
    static func decide(_ session: RunSession, givesUpAfterBanks: Int = 3, givesUpAfter seconds: TimeInterval = 40) -> AutopilotDecision {
        let cart = session.cart
        let now = session.elapsed
        var decision = AutopilotDecision(targetX: cart.x)
        guard !cart.isSwitching else { return decision }

        let givesUp = session.banks >= givesUpAfterBanks || now >= seconds
        let onRail = session.projectiles.filter { $0.rail == cart.rail }
        let threats = onRail.filter { $0.payload.isBomb && $0.landsAt - now < 0.9 && abs($0.x - cart.x) < 0.32 }
        if givesUp {
            // Wind the shift down: stand under the next bomb on this rail, or hop to the other one.
            if let bomb = onRail.filter({ $0.payload.isBomb }).min(by: { $0.landsAt < $1.landsAt }) {
                decision.targetX = bomb.x
            } else {
                decision.switchRail = session.projectiles.contains { $0.payload.isBomb && $0.rail != cart.rail }
            }
        } else if let bomb = threats.min(by: { $0.landsAt < $1.landsAt }) {
            var away = bomb.x + (cart.x >= bomb.x ? 0.42 : -0.42)
            if abs(away) > Balance.trackLimit { away = bomb.x + (cart.x >= bomb.x ? -0.42 : 0.42) }
            decision.targetX = away
        } else if session.cargoCount >= 5 || session.heatFraction > 0.65 {
            decision.targetX = RunSession.bankSide(of: cart.rail) * Balance.trackLimit
        } else if let coin = onRail.filter({ !$0.payload.isBomb }).min(by: { $0.landsAt < $1.landsAt }) {
            decision.targetX = coin.x
        } else if let bolt = session.lightnings.first(where: { $0.rail == cart.rail }) {
            decision.targetX = bolt.x
        } else if session.cargoCount > 0 {
            decision.targetX = RunSession.bankSide(of: cart.rail) * Balance.trackLimit
        } else {
            let otherRailCoins = session.projectiles.filter { $0.rail != cart.rail && !$0.payload.isBomb }
            let otherRailBombs = session.projectiles.filter { $0.rail != cart.rail && $0.payload.isBomb }
            decision.switchRail = otherRailCoins.count >= 2 && otherRailBombs.isEmpty
        }

        // Smash a boulder that stands between the cart and its goal.
        let direction = decision.targetX - cart.x
        let blocking = session.boulders.contains { boulder in
            boulder.rail == cart.rail
                && (boulder.x - cart.x) * direction > 0
                && abs(boulder.x - cart.x) < Balance.cartHalfWidth + Balance.boulderHalfWidth + 0.12
        }
        decision.dash = blocking && cart.dashCooldown <= 0
        return decision
    }
}
