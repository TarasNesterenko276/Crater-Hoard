import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Procedural app icon for Crater Hoard.
// Usage: swift gen.swift <output-directory>

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func makeContext(_ size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    return ctx
}

func save(_ ctx: CGContext, to url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

// Seeded random so both sizes render identically.
struct Rng {
    var state: UInt64
    mutating func next() -> Double {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return Double((state &* 2685821657736338717) >> 11) / Double(1 << 53)
    }
    mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + (r.upperBound - r.lowerBound) * next() }
}

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    rgb(CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, a)
}

// MARK: - Crater Hoard: a volcano erupting a fountain of coins onto a balanced stack.

func drawCraterHoard(size: Int) -> CGContext {
    let ctx = makeContext(size)
    let s = CGFloat(size)
    let u = s / 1024
    var rng = Rng(state: 0xC0_1215)
    // CoreGraphics origin is bottom-left here.
    ctx.drawLinearGradient(gradient([hex(0x0E3A3A), hex(0x1C2A33), hex(0x2A1A22)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    // Warm glow behind the crater.
    ctx.drawRadialGradient(gradient([hex(0xFFB24A, 0.75), hex(0xFF6A2A, 0.25), hex(0xFF6A2A, 0)], [0, 0.4, 1]),
                           startCenter: CGPoint(x: s * 0.5, y: s * 0.42), startRadius: 0,
                           endCenter: CGPoint(x: s * 0.5, y: s * 0.42), endRadius: s * 0.55, options: [])
    // Stars.
    for _ in 0..<40 {
        let p = CGPoint(x: rng.range(0...1) * s, y: rng.range(0.6...1) * s)
        ctx.setFillColor(rgb(1, 1, 1, rng.range(0.3...0.8)))
        ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: 4 * u, height: 4 * u))
    }

    let outline = hex(0x1E1412)
    ctx.setLineJoin(.round); ctx.setLineCap(.round)

    // Volcano.
    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: -20 * u, y: 0))
    cone.addLine(to: CGPoint(x: 330 * u, y: 380 * u))
    cone.addQuadCurve(to: CGPoint(x: 694 * u, y: 380 * u), control: CGPoint(x: 512 * u, y: 330 * u))
    cone.addLine(to: CGPoint(x: 1044 * u, y: 0))
    cone.closeSubpath()
    ctx.saveGState(); ctx.addPath(cone); ctx.clip()
    ctx.drawLinearGradient(gradient([hex(0x6B4E46), hex(0x3A2A2C), hex(0x1E1618)], [0, 0.5, 1]),
                           start: CGPoint(x: 300 * u, y: 380 * u), end: CGPoint(x: 700 * u, y: 0), options: [])
    // Lava rivulets.
    ctx.setStrokeColor(hex(0xFF7A2A)); ctx.setLineWidth(16 * u)
    for (x0, x1) in [(420.0, 330.0), (600.0, 690.0)] {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x0 * u, y: 370 * u))
        p.addCurve(to: CGPoint(x: x1 * u, y: 0), control1: CGPoint(x: (x0 - 40) * u, y: 260 * u), control2: CGPoint(x: (x1 + 30) * u, y: 140 * u))
        ctx.addPath(p); ctx.strokePath()
    }
    ctx.restoreGState()
    ctx.addPath(cone); ctx.setStrokeColor(outline); ctx.setLineWidth(14 * u); ctx.strokePath()
    // Crater mouth.
    let mouth = CGRect(x: 340 * u, y: 352 * u, width: 344 * u, height: 70 * u)
    ctx.setFillColor(hex(0xFFC94E)); ctx.fillEllipse(in: mouth)
    ctx.setStrokeColor(outline); ctx.setLineWidth(12 * u); ctx.strokeEllipse(in: mouth)

    // Fountain of coins (front view ellipses tilted at random).
    func coin(_ c: CGPoint, _ r: CGFloat, _ squash: CGFloat, _ rot: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: rot)
        let rect = CGRect(x: -r, y: -r * squash, width: r * 2, height: r * 2 * squash)
        ctx.setFillColor(hex(0x95651B)); ctx.fillEllipse(in: rect.offsetBy(dx: 0, dy: -7 * u))
        ctx.addEllipse(in: rect.offsetBy(dx: 0, dy: -7 * u)); ctx.setStrokeColor(outline); ctx.setLineWidth(9 * u); ctx.strokePath()
        ctx.saveGState(); ctx.addEllipse(in: rect); ctx.clip()
        ctx.drawLinearGradient(gradient([hex(0xFBE6A0), hex(0xE8B84A), hex(0xB8822A)]), start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
        ctx.restoreGState()
        ctx.addEllipse(in: rect); ctx.setStrokeColor(outline); ctx.setLineWidth(9 * u); ctx.strokePath()
        ctx.addEllipse(in: rect.insetBy(dx: r * 0.28, dy: r * 0.28 * squash)); ctx.setStrokeColor(hex(0xB8822A)); ctx.setLineWidth(6 * u); ctx.strokePath()
        ctx.restoreGState()
    }
    let coins: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (512, 560, 84, 0.9, 0.1), (330, 690, 66, 0.6, -0.5), (700, 700, 70, 0.7, 0.45),
        (470, 830, 58, 0.5, 0.3), (612, 870, 52, 0.85, -0.2), (215, 520, 46, 0.4, 0.7), (820, 540, 48, 0.55, -0.6)
    ]
    for (x, y, r, sq, rot) in coins { coin(CGPoint(x: x * u, y: y * u), r * u, sq, rot) }
    // Sparks.
    for _ in 0..<26 {
        let p = CGPoint(x: rng.range(0.2...0.8) * s, y: rng.range(0.38...0.9) * s)
        let r = rng.range(5...12) * u
        ctx.setFillColor(hex(0xFFC94E, 0.9)); ctx.fillEllipse(in: CGRect(x: p.x - r / 2, y: p.y - r / 2, width: r, height: r))
    }
    return ctx
}

for size in [512, 1024] {
    save(drawCraterHoard(size: size), to: outputDirectory.appendingPathComponent("CraterHoard-\(size).png"))
}
