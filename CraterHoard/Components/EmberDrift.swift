import SwiftUI

/// Slowly rising embers drawn with `Canvas`. Freezes when `isActive` is false
/// (reduce motion, UI tests) so the screen can become idle.
struct EmberDrift: View {
    var isActive: Bool
    var count = 26

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive)) { timeline in
            Canvas { context, size in
                let time = isActive ? timeline.date.timeIntervalSinceReferenceDate : 0
                for index in 0..<count {
                    let seed = Double(index) * 12.9898
                    let speed = 14 + (sin(seed) + 1) * 10
                    let x = (sin(seed * 3.1) + 1) / 2 * size.width + sin(time * 0.6 + seed) * 12
                    let travel = (time * speed + seed * 40).truncatingRemainder(dividingBy: Double(size.height) + 40)
                    let y = Double(size.height) + 20 - travel
                    let radius = 1.2 + (cos(seed * 1.7) + 1) * 1.1
                    let fade = min(1, travel / 120) * (0.4 + 0.4 * sin(time * 2 + seed))
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -radius * 1.5, dy: -radius * 1.5)), with: .color(Theme.Colors.lava.opacity(fade * 0.25)))
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.Colors.lavaHot.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
