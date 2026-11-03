// Crater Hoard art generator.
// Paints every bitmap the app uses (backgrounds, coins, keepers, jars, HUD parts, guide art)
// with CoreGraphics and writes image sets into the asset catalog. Deterministic.
// Usage: swift generate_assets.swift "<path>/Assets.xcassets/Generated" [preview-dir]

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(.white, t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.05, 0.06, 0.12), t) }
    static let white = Col(1, 1, 1)
    static let ink = Col(hex: 0x1B2340)
}

struct Rng {
    var s: UInt64
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Canvas (top-left origin)

var ctx: CGContext!
var canvasW: CGFloat = 0, canvasH: CGFloat = 0

func begin(_ w: Int, _ h: Int) {
    canvasW = CGFloat(w); canvasH = CGFloat(h)
    ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

/// Writes the current canvas as `<name>.imageset` marked @3x so 3 px = 1 pt.
func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
}

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func linearFill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func radialFill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(0)]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.05, 0.08, 0.2, 0.35), _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -offsetY), blur: blur, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}

// MARK: - Crater Hoard helpers (drawing in points, written at @3x)

let S: CGFloat = 3
func beginPt(_ w: CGFloat, _ h: CGFloat) {
    begin(Int(w * S), Int(h * S))
    ctx.scaleBy(x: S, y: S)
    canvasW = w; canvasH = h
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

func label(_ s: String, _ p: CGPoint, size: CGFloat, color: Col, outline: Col? = nil, outlineWidth: CGFloat = 4, kern: CGFloat = 1.5) {
    let font = NSFont(name: "Rockwell-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .black)
    func draw(_ attrs: [NSAttributedString.Key: Any]) {
        let str = NSAttributedString(string: s, attributes: attrs)
        let sz = str.size()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        str.draw(at: CGPoint(x: p.x - sz.width / 2, y: p.y - sz.height / 2))
        NSGraphicsContext.restoreGraphicsState()
    }
    if let outline {
        draw([.font: font, .kern: kern, .foregroundColor: NSColor(cgColor: outline.cg)!, .strokeColor: NSColor(cgColor: outline.cg)!, .strokeWidth: outlineWidth * 2])
    }
    draw([.font: font, .kern: kern, .foregroundColor: NSColor(cgColor: color.cg)!])
}

/// Palette: cave copper and patina over warm basalt.
enum C {
    static let outline = Col(hex: 0x1E1412)
    static let basalt = Col(hex: 0x17141A)
    static let rock = Col(hex: 0x2E2528)
    static let rockMid = Col(hex: 0x433638)
    static let rockLight = Col(hex: 0x65524E)
    static let copper = Col(hex: 0xC8743A)
    static let copperDark = Col(hex: 0x7A3F1F)
    static let copperLight = Col(hex: 0xF0A868)
    static let patina = Col(hex: 0x4FB3A0)
    static let patinaDark = Col(hex: 0x22665C)
    static let patinaLight = Col(hex: 0x9BE0CF)
    static let gold = Col(hex: 0xE8B84A)
    static let goldLight = Col(hex: 0xFBE6A0)
    static let goldDark = Col(hex: 0x95651B)
    static let silver = Col(hex: 0xCBD2DA)
    static let silverLight = Col(hex: 0xF4F7FA)
    static let silverDark = Col(hex: 0x6B7684)
    static let obsidian = Col(hex: 0x1F1A2C)
    static let obsidianShine = Col(hex: 0x7C6EBB)
    static let lava = Col(hex: 0xFF6A2A)
    static let lavaHot = Col(hex: 0xFFC94E)
    static let lavaDeep = Col(hex: 0xA62A10)
    static let paper = Col(hex: 0xF3E6CC)
    static let paperShade = Col(hex: 0xD9C49E)
    static let wood = Col(hex: 0x7A4B2A)
    static let woodDark = Col(hex: 0x4A2C18)
    static let woodLight = Col(hex: 0xA8723F)
    static let iron = Col(hex: 0x3B3F46)
    static let ironLight = Col(hex: 0x6E747E)
    static let cream = Col(hex: 0xFFF6E2)
}

let ow: CGFloat = 1.6 // standard outline width in points
func fill(_ rect: CGRect, _ c: Col) { fill(CGPath(rect: rect, transform: nil), c) }

func outlined(_ path: CGPath, _ fillCol: Col, width: CGFloat = ow) { fill(path, fillCol); stroke(path, C.outline, width) }
func outlinedGradient(_ path: CGPath, _ cols: [Col], _ a: CGPoint, _ b: CGPoint, width: CGFloat = ow) {
    linearFill(path, cols, a, b); stroke(path, C.outline, width)
}
func softShadow(_ path: CGPath, dy: CGFloat = 3, blur: CGFloat = 6, alpha: CGFloat = 0.45) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -dy), blur: blur, color: Col(0, 0, 0, alpha).cg)
    fill(path, Col(0, 0, 0, 0.6))
    ctx.restoreGState()
}
func clipped(_ path: CGPath, _ body: () -> Void) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip(); body(); ctx.restoreGState()
}
func line(_ a: CGPoint, _ b: CGPoint, _ c: Col, _ w: CGFloat) {
    let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); stroke(p, c, w)
}
func rivet(_ c: CGPoint, _ r: CGFloat = 2.2) {
    fill(circle(c, r), C.copperDark)
    fill(circle(P(c.x - r * 0.3, c.y - r * 0.3), r * 0.55), C.copperLight)
}

/// Lumpy rock outline: a polygon jittered around an ellipse.
func rockShape(_ rect: CGRect, seed: UInt64, points n: Int = 14, jitter: CGFloat = 0.12) -> CGPath {
    var g = Rng(s: seed)
    var pts: [CGPoint] = []
    for i in 0..<n {
        let a = CGFloat(i) / CGFloat(n) * .pi * 2
        let k = 1 - jitter + g.r(0, jitter * 2)
        pts.append(P(rect.midX + cos(a) * rect.width / 2 * k, rect.midY + sin(a) * rect.height / 2 * k))
    }
    return poly(pts)
}

// MARK: - Coins and ingots (side view)

func coinMetalCols(_ m: String) -> (Col, Col, Col) {
    switch m {
    case "copper": return (C.copperLight, C.copper, C.copperDark)
    case "silver": return (C.silverLight, C.silver, C.silverDark)
    case "gold": return (C.goldLight, C.gold, C.goldDark)
    default: return (C.obsidianShine, C.obsidian, Col(hex: 0x0B0912))
    }
}

func drawCoinSide(_ m: String, w: CGFloat, t: CGFloat) {
    beginPt(w + 6, t + 6)
    let body = rr(R(3, 3, w, t), t * 0.42)
    let (light, mid, dark) = coinMetalCols(m)
    linearFill(body, [light, mid, dark], P(0, 3), P(0, 3 + t), [0, 0.45, 1])
    clipped(body) {
        if m == "obsidian" {
            // Glassy facets.
            fill(poly([P(3 + w * 0.12, 3), P(3 + w * 0.32, 3), P(3 + w * 0.2, 3 + t)]), Col(1, 1, 1, 0.16))
            fill(poly([P(3 + w * 0.55, 3), P(3 + w * 0.62, 3), P(3 + w * 0.5, 3 + t), P(3 + w * 0.44, 3 + t)]), Col(1, 1, 1, 0.1))
            fill(R(3, 3 + t * 0.15, w, t * 0.12), C.obsidianShine.alpha(0.45))
        } else {
            // Milled edge.
            var x: CGFloat = 3 + t * 0.4
            while x < 3 + w - t * 0.4 {
                line(P(x, 3 + t * 0.35), P(x, 3 + t * 0.92), dark.alpha(0.55), 0.9)
                x += 3.4
            }
            fill(R(3, 3 + t * 0.08, w, t * 0.2), light.alpha(0.75))
        }
    }
    stroke(body, C.outline, ow)
    finish("coin_\(m)")
}

func drawIngot(_ m: String) {
    let w: CGFloat = 118, t: CGFloat = 24
    beginPt(w + 6, t + 6)
    let inset: CGFloat = 9
    let shape = CGMutablePath()
    shape.move(to: P(3 + inset, 3)); shape.addLine(to: P(3 + w - inset, 3))
    shape.addLine(to: P(3 + w, 3 + t)); shape.addLine(to: P(3, 3 + t)); shape.closeSubpath()
    let (light, mid, dark) = coinMetalCols(m)
    linearFill(shape, [light, mid, dark], P(0, 3), P(0, 3 + t), [0, 0.5, 1])
    clipped(shape) {
        fill(poly([P(3 + inset, 3), P(3 + w - inset, 3), P(3 + w - inset - 3, 3 + 5), P(3 + inset + 3, 3 + 5)]), light.lighter(0.4).alpha(0.8))
        // Stamped crater mark.
        let cx = 3 + w / 2, cy = 3 + t * 0.6
        let mark = poly([P(cx - 10, cy + 5), P(cx - 4, cy - 4), P(cx - 1.5, cy - 1), P(cx + 1.5, cy - 1), P(cx + 4, cy - 4), P(cx + 10, cy + 5)])
        fill(mark, dark.alpha(0.55))
        stroke(mark, light.alpha(0.7), 0.6)
    }
    stroke(shape, C.outline, ow)
    finish("ingot_\(m)")
}

// MARK: - Scene parts

func drawBeam() {
    let w: CGFloat = 280, h: CGFloat = 34
    beginPt(w, h)
    let slab = rr(R(2, 7, w - 4, 20), 5)
    linearFill(slab, [C.rockLight, C.rockMid, C.rock], P(0, 7), P(0, 27))
    clipped(slab) {
        var g = Rng(s: 41)
        for _ in 0..<40 { fill(circle(P(g.r(4, w - 4), g.r(9, 26)), g.r(0.5, 1.6)), Col(0, 0, 0, 0.18)) }
        fill(R(2, 8, w - 4, 3), Col(1, 1, 1, 0.12))
    }
    stroke(slab, C.outline, ow)
    for x in [CGFloat(14), w / 2, w - 14] {
        let band = rr(R(x - 8, 4, 16, 26), 3)
        outlinedGradient(band, [C.copperLight, C.copper, C.copperDark], P(0, 4), P(0, 30))
        rivet(P(x, 10)); rivet(P(x, 24))
    }
    finish("beam")
}

func drawFulcrum() {
    beginPt(150, 160)
    let shape = poly([P(75, 6), P(96, 40), P(118, 92), P(146, 156), P(4, 156), P(30, 96), P(54, 40)])
    softShadow(shape, dy: 2, blur: 8, alpha: 0.5)
    // Lighter basalt with a warm rim so the rock reads against the dark shaft.
    linearFill(shape, [C.rockLight.lighter(0.25), C.rockLight, C.rockMid, C.rock], P(40, 0), P(110, 160))
    clipped(shape) {
        var g = Rng(s: 7)
        for _ in 0..<9 {
            let x = g.r(20, 130), y = g.r(40, 150)
            line(P(x, y), P(x + g.r(-14, 14), y + g.r(6, 18)), Col(0, 0, 0, 0.35), 1.2)
        }
        // Lava glow from below.
        fill(R(0, 120, 150, 40), C.lava.alpha(0.18))
    }
    stroke(shape, C.lava.alpha(0.55), 5)
    stroke(shape, C.outline, ow)
    // Copper pin.
    outlinedGradient(circle(P(75, 12), 9), [C.copperLight, C.copper, C.copperDark], P(66, 4), P(84, 22))
    fill(circle(P(75, 12), 3), C.copperDark)
    finish("fulcrum")
}

func drawClaw() {
    beginPt(96, 64)
    // Prongs.
    for side in [CGFloat(-1), 1] {
        let p = CGMutablePath()
        p.move(to: P(48 + side * 12, 20))
        p.addCurve(to: P(48 + side * 40, 58), control1: P(48 + side * 38, 22), control2: P(48 + side * 44, 44))
        p.addLine(to: P(48 + side * 33, 60))
        p.addCurve(to: P(48 + side * 9, 28), control1: P(48 + side * 34, 44), control2: P(48 + side * 28, 30))
        p.closeSubpath()
        outlinedGradient(p, [C.ironLight, C.iron], P(0, 20), P(0, 60))
    }
    let housing = rr(R(26, 6, 44, 22), 6)
    outlinedGradient(housing, [C.copperLight, C.copper, C.copperDark], P(0, 6), P(0, 28))
    fill(R(30, 9, 36, 3), C.patinaLight.alpha(0.6))
    rivet(P(33, 20)); rivet(P(63, 20))
    outlined(circle(P(48, 6), 5), C.ironLight)
    finish("claw")
}

func drawChain() {
    beginPt(18, 900)
    var y: CGFloat = 0
    var i = 0
    while y < 900 {
        if i % 2 == 0 {
            let link = rr(R(4, y, 10, 22), 5)
            stroke(link, C.outline, 4.2); stroke(link, C.ironLight, 2.2)
        } else {
            line(P(9, y - 2), P(9, y + 24), C.outline, 4.2); line(P(9, y - 2), P(9, y + 24), C.iron, 2.2)
        }
        y += 18; i += 1
    }
    finish("chain")
}

func drawLavaCrust() {
    beginPt(1200, 60)
    let p = CGMutablePath()
    p.move(to: P(0, 60)); p.addLine(to: P(0, 16))
    var x: CGFloat = 0
    var g = Rng(s: 99)
    while x < 1200 {
        let nx = x + g.r(30, 60)
        p.addQuadCurve(to: P(nx, g.r(10, 20)), control: P((x + nx) / 2, g.r(2, 10)))
        x = nx
    }
    p.addLine(to: P(1200, 60)); p.closeSubpath()
    linearFill(p, [C.lavaHot, C.lava, C.lavaDeep.mix(C.lava, 0.6)], P(0, 6), P(0, 60), [0, 0.3, 1])
    clipped(p) {
        var g2 = Rng(s: 5)
        for _ in 0..<70 {
            let c = P(g2.r(0, 1200), g2.r(24, 58))
            fill(rockShape(R(c.x, c.y, g2.r(10, 34), g2.r(5, 10)), seed: UInt64(c.x * 10)), C.lavaDeep.mix(C.basalt, 0.4).alpha(0.7))
        }
        for _ in 0..<40 { glow(P(g2.r(0, 1200), g2.r(16, 30)), g2.r(4, 10), C.lavaHot.alpha(0.8)) }
    }
    finish("lava_crust")
}

func drawGlow() {
    begin(128, 128)
    ctx.drawRadialGradient(gradient([Col(1, 1, 1, 1), Col(1, 1, 1, 0.35), Col(1, 1, 1, 0)], [0, 0.35, 1]),
                           startCenter: P(64, 64), startRadius: 0, endCenter: P(64, 64), endRadius: 64, options: [])
    finish("fx_glow")
}

// MARK: - Backgrounds

func rockWall(_ rect: CGRect, seed: UInt64, base: Col, layers: Int = 18) {
    var g = Rng(s: seed)
    fill(CGPath(rect: rect, transform: nil), base)
    for i in 0..<layers {
        let y = rect.minY + CGFloat(i) / CGFloat(layers) * rect.height
        let p = CGMutablePath()
        p.move(to: P(rect.minX, y))
        var x = rect.minX
        while x < rect.maxX {
            let nx = x + g.r(20, 60)
            p.addLine(to: P(nx, y + g.r(-6, 6)))
            x = nx
        }
        p.addLine(to: P(rect.maxX, y + rect.height / CGFloat(layers) + 4)); p.addLine(to: P(rect.minX, y + rect.height / CGFloat(layers) + 4)); p.closeSubpath()
        fill(p, base.mix(i % 2 == 0 ? C.rockLight : C.basalt, g.r(0.05, 0.3)))
    }
    for _ in 0..<Int(rect.width * rect.height / 900) {
        fill(circle(P(g.r(rect.minX, rect.maxX), g.r(rect.minY, rect.maxY)), g.r(0.4, 1.4)), Col(0, 0, 0, g.r(0.1, 0.3)))
    }
}

func drawShaft() {
    let w: CGFloat = 430, h: CGFloat = 932
    beginPt(w, h)
    // Deep shaft with crater light above and lava light below.
    linearFill(CGPath(rect: R(0, 0, w, h), transform: nil),
               [Col(hex: 0x3A2A3E), Col(hex: 0x241B24), Col(hex: 0x17121A), Col(hex: 0x2A1612), Col(hex: 0x4A1E10)],
               P(0, 0), P(0, h), [0, 0.22, 0.55, 0.82, 1])
    // Crater mouth with dusk sky and smoke.
    let mouth = CGMutablePath()
    mouth.move(to: P(90, 0)); mouth.addQuadCurve(to: P(340, 0), control: P(215, 170))
    clipped(mouth) {
        linearFill(CGPath(rect: R(0, 0, w, 120), transform: nil), [Col(hex: 0x2B3A5E), Col(hex: 0x7A4A66), Col(hex: 0xE08A52)], P(0, 0), P(0, 110))
        var g = Rng(s: 3)
        for _ in 0..<16 { fill(circle(P(g.r(110, 320), g.r(0, 60)), g.r(10, 26)), Col(hex: 0x3B2C3A, 0.35)) }
        for _ in 0..<12 { fill(circle(P(g.r(110, 320), g.r(2, 40)), 0.8), Col(1, 1, 1, 0.8)) }
    }
    glow(P(215, 40), 220, Col(hex: 0xE08A52, 0.28))
    // Side walls.
    for (side, seed) in [(CGFloat(0), UInt64(11)), (1, 12)] {
        let wall = CGMutablePath()
        var g = Rng(s: seed)
        let edge: (CGFloat) -> CGFloat = { y in side == 0 ? 52 + sin(y / 70) * 12 : w - 52 - cos(y / 64) * 12 }
        wall.move(to: P(side == 0 ? 0 : w, 0))
        var y: CGFloat = 0
        while y <= h {
            wall.addLine(to: P(edge(y) + g.r(-6, 6), y)); y += 24
        }
        wall.addLine(to: P(side == 0 ? 0 : w, h)); wall.closeSubpath()
        clipped(wall) { rockWall(R(0, 0, w, h), seed: seed * 3, base: C.rock, layers: 30) }
        stroke(wall, C.outline.alpha(0.8), 2)
        // Rim light from the lava.
        clipped(wall) { linearFill(CGPath(rect: R(0, h * 0.7, w, h * 0.3), transform: nil), [C.lava.alpha(0), C.lava.alpha(0.35)], P(0, h * 0.7), P(0, h)) }
    }
    // Copper pipes and old ladder bolts on the walls.
    for x in [CGFloat(22), w - 22] {
        let pipe = rr(R(x - 5, 140, 10, 700), 5)
        outlinedGradient(pipe, [C.copperDark, C.copperLight, C.copper, C.copperDark], P(x - 5, 0), P(x + 5, 0))
        for y in stride(from: CGFloat(190), to: 820, by: 130) {
            outlined(rr(R(x - 8, y, 16, 8), 2), C.patina)
        }
    }
    // Floating embers.
    var g = Rng(s: 77)
    for _ in 0..<40 { glow(P(g.r(60, w - 60), g.r(h * 0.35, h)), g.r(2, 5), C.lavaHot.alpha(0.9)) }
    glow(P(w / 2, h + 40), 340, C.lava.alpha(0.45))
    finish("bg_shaft")
}

func drawVault() {
    let w: CGFloat = 430, h: CGFloat = 932
    beginPt(w, h)
    rockWall(R(0, 0, w, h), seed: 21, base: Col(hex: 0x2A2124), layers: 34)
    // Arched cave chamber, carved back.
    let arch = CGMutablePath()
    arch.move(to: P(36, h - 70))
    arch.addLine(to: P(36, 330))
    arch.addQuadCurve(to: P(w - 36, 330), control: P(w / 2, 40))
    arch.addLine(to: P(w - 36, h - 70)); arch.closeSubpath()
    clipped(arch) {
        linearFill(CGPath(rect: R(0, 0, w, h), transform: nil), [Col(hex: 0x3E2C2A), Col(hex: 0x231B1E), Col(hex: 0x1A1417)], P(0, 100), P(0, h))
        rockWall(R(0, 520, w, 420), seed: 22, base: Col(hex: 0x221A1C).alpha(0.6), layers: 10)
        glow(P(w / 2, 150), 260, Col(hex: 0xFFB060, 0.35))
    }
    stroke(arch, C.outline, 3)
    // Crater shaft light falling in from above.
    let beam = poly([P(w / 2 - 40, 60), P(w / 2 + 40, 60), P(w / 2 + 150, h - 120), P(w / 2 - 150, h - 120)])
    fill(beam, Col(hex: 0xFFC27A, 0.06))
    // Mine timbers.
    for x in [CGFloat(18), w - 18] {
        let post = rr(R(x - 14, 220, 28, h - 260), 4)
        outlinedGradient(post, [C.woodLight, C.wood, C.woodDark], P(x - 14, 0), P(x + 14, 0))
        clipped(post) { for y in stride(from: CGFloat(240), to: h, by: 22) { line(P(x - 10, y), P(x + 8, y + 6), C.woodDark.alpha(0.5), 0.8) } }
    }
    let lintel = rr(R(0, 206, w, 26), 4)
    outlinedGradient(lintel, [C.woodLight, C.wood, C.woodDark], P(0, 206), P(0, 232))
    for x in [CGFloat(18), w - 18] { rivet(P(x, 219), 3.2) }
    // Floor with scattered coins.
    let floor = CGMutablePath()
    floor.move(to: P(0, h - 120)); floor.addQuadCurve(to: P(w, h - 120), control: P(w / 2, h - 160))
    floor.addLine(to: P(w, h)); floor.addLine(to: P(0, h)); floor.closeSubpath()
    linearFill(floor, [Col(hex: 0x3A2C28), Col(hex: 0x201819)], P(0, h - 150), P(0, h))
    stroke(floor, C.outline, 2)
    var g = Rng(s: 31)
    for _ in 0..<26 {
        let c = P(g.r(30, w - 30), g.r(h - 110, h - 20))
        let e = ellipse(R(c.x - 6, c.y - 2.5, 12, 5))
        fill(e, [C.gold, C.copper, C.silver][Int(g.r(0, 2.99))])
        stroke(e, C.outline, 0.8)
    }
    // Hanging lamps.
    for x in [CGFloat(90), w - 90] {
        line(P(x, 232), P(x, 262), C.iron, 1.5)
        glow(P(x, 274), 60, Col(hex: 0xFFB45A, 0.5))
        outlined(rr(R(x - 7, 262, 14, 20), 4), C.lavaHot)
        outlined(rr(R(x - 9, 258, 18, 5), 2), C.copper)
    }
    finish("bg_vault")
}

func drawPaper() {
    beginPt(200, 200)
    fill(CGPath(rect: R(0, 0, 200, 200), transform: nil), C.paper)
    var g = Rng(s: 8)
    for _ in 0..<220 {
        let x = g.r(0, 200), y = g.r(0, 200)
        line(P(x, y), P(x + g.r(-6, 6), y + g.r(-2, 2)), C.paperShade.alpha(g.r(0.15, 0.4)), 0.4)
    }
    for _ in 0..<60 { fill(circle(P(g.r(0, 200), g.r(0, 200)), g.r(0.3, 0.9)), C.paperShade.alpha(0.35)) }
    finish("tex_paper")
}

func drawSlate() {
    beginPt(200, 200)
    fill(CGPath(rect: R(0, 0, 200, 200), transform: nil), Col(hex: 0x2A3133))
    var g = Rng(s: 13)
    for _ in 0..<160 {
        let x = g.r(0, 200), y = g.r(0, 200)
        line(P(x, y), P(x + g.r(-14, 14), y + g.r(-3, 3)), Col(1, 1, 1, g.r(0.02, 0.07)), g.r(0.5, 2.5))
    }
    finish("tex_slate")
}

func drawCoreRock() {
    beginPt(100, 100)
    var g = Rng(s: 17)
    for _ in 0..<140 {
        fill(circle(P(g.r(0, 100), g.r(0, 100)), g.r(0.3, 1.5)), (g.next() > 0.5 ? Col(1, 1, 1, 0.16) : Col(0, 0, 0, 0.18)))
    }
    for _ in 0..<12 {
        let x = g.r(0, 100), y = g.r(0, 100)
        line(P(x, y), P(x + g.r(8, 20), y + g.r(-2, 2)), Col(0, 0, 0, 0.15), 0.6)
    }
    finish("core_rock")
}

// MARK: - Hub items

func drawLogo() {
    beginPt(360, 120)
    let plank = rr(R(10, 30, 340, 62), 8)
    softShadow(plank, dy: 4, blur: 8)
    outlinedGradient(plank, [C.woodLight, C.wood, C.woodDark], P(0, 30), P(0, 92), width: 2.2)
    clipped(plank) {
        var g = Rng(s: 2)
        for _ in 0..<14 { let y = g.r(34, 90); line(P(10, y), P(350, y + g.r(-3, 3)), C.woodDark.alpha(0.35), 0.8) }
    }
    for x in [CGFloat(10), 350] {
        let bracket = rr(R(x - 12, 24, 24, 74), 5)
        outlinedGradient(bracket, [C.copperLight, C.copper, C.copperDark], P(0, 24), P(0, 98))
        rivet(P(x, 36), 2.6); rivet(P(x, 86), 2.6)
    }
    // Chains up to the ceiling.
    for x in [CGFloat(60), 300] { line(P(x, 0), P(x, 30), C.outline, 3.5); line(P(x, 0), P(x, 30), C.ironLight, 1.6) }
    label("CRATER HOARD", P(180, 61), size: 34, color: C.goldLight, outline: C.outline, outlineWidth: 3.5, kern: 2)
    finish("logo_wordmark")
}

func coinStackFront(_ cx: CGFloat, _ baseY: CGFloat, count: Int, w: CGFloat, metal: String) {
    let (light, mid, dark) = coinMetalCols(metal)
    for i in 0..<count {
        let y = baseY - CGFloat(i) * 6
        let side = rr(R(cx - w / 2, y - 3, w, 7), 3)
        outlinedGradient(side, [mid, dark], P(0, y - 3), P(0, y + 4), width: 1)
        let top = ellipse(R(cx - w / 2, y - 6, w, 7))
        fill(top, light); stroke(top, C.outline, 1)
    }
}

func drawHubBalance() {
    beginPt(200, 180)
    glow(P(100, 90), 110, Col(hex: 0xFFB45A, 0.35))
    // Fulcrum rock.
    let rock = poly([P(100, 98), P(128, 172), P(72, 172)])
    outlinedGradient(rock, [C.rockLight, C.rock], P(80, 100), P(120, 172))
    // Beam tilted a little.
    ctx.saveGState(); ctx.translateBy(x: 100, y: 100); ctx.rotate(by: -0.06)
    let beamPath = rr(R(-88, -6, 176, 12), 4)
    outlinedGradient(beamPath, [C.rockLight, C.rockMid], P(0, -6), P(0, 6))
    for x in [CGFloat(-80), 0, 80] { outlined(rr(R(x - 5, -8, 10, 16), 2), C.copper, width: 1.2) }
    // Hoard: side-view coins and an ingot.
    let pieces: [(CGFloat, CGFloat, CGFloat, String)] = [(-46, 34, 9, "copper"), (-48, 30, 8, "copper"), (-44, 26, 8, "silver"), (20, 40, 9, "gold"), (18, 36, 8, "copper"), (22, 30, 8, "silver"), (16, 26, 8, "gold")]
    var y: CGFloat = -6
    var lastX: CGFloat = 999
    for (x, w, t, m) in pieces {
        if x != lastX && abs(x - lastX) > 20 { y = -6 }
        lastX = x
        y -= t
        let (l, mi, d) = coinMetalCols(m)
        let c = rr(R(x - w / 2, y, w, t), t * 0.4)
        linearFill(c, [l, mi, d], P(0, y), P(0, y + t)); stroke(c, C.outline, 1.1)
    }
    let ingot = poly([P(-26, -74), P(26, -74), P(32, -60), P(-32, -60)])
    outlinedGradient(ingot, [C.goldLight, C.gold, C.goldDark], P(0, -74), P(0, -60))
    ctx.restoreGState()
    var g = Rng(s: 4)
    for _ in 0..<10 { glow(P(g.r(30, 170), g.r(10, 80)), g.r(2, 4), C.goldLight) }
    finish("hub_balance")
}

func drawJarGlass(_ rect: CGRect) -> CGPath {
    let p = CGMutablePath()
    let neckW = rect.width * 0.4
    p.move(to: P(rect.midX - neckW / 2, rect.minY))
    p.addLine(to: P(rect.midX + neckW / 2, rect.minY))
    p.addLine(to: P(rect.midX + neckW / 2, rect.minY + rect.height * 0.14))
    p.addCurve(to: P(rect.maxX, rect.minY + rect.height * 0.42), control1: P(rect.maxX, rect.minY + rect.height * 0.2), control2: P(rect.maxX, rect.minY + rect.height * 0.3))
    p.addLine(to: P(rect.maxX, rect.maxY - 10))
    p.addQuadCurve(to: P(rect.maxX - 10, rect.maxY), control: P(rect.maxX, rect.maxY))
    p.addLine(to: P(rect.minX + 10, rect.maxY))
    p.addQuadCurve(to: P(rect.minX, rect.maxY - 10), control: P(rect.minX, rect.maxY))
    p.addLine(to: P(rect.minX, rect.minY + rect.height * 0.42))
    p.addCurve(to: P(rect.midX - neckW / 2, rect.minY + rect.height * 0.14), control1: P(rect.minX, rect.minY + rect.height * 0.3), control2: P(rect.minX, rect.minY + rect.height * 0.2))
    p.closeSubpath()
    return p
}

func drawShelfItem() {
    beginPt(140, 140)
    glow(P(70, 70), 80, Col(hex: 0x6FE0C8, 0.25))
    let plank = rr(R(6, 108, 128, 12), 3)
    outlinedGradient(plank, [C.woodLight, C.woodDark], P(0, 108), P(0, 120))
    for x in [CGFloat(20), 120] { outlined(poly([P(x - 4, 120), P(x + 4, 120), P(x, 134)]), C.copper, width: 1.2) }
    let jars: [(CGFloat, CGFloat, Col)] = [(36, 54, C.patina), (70, 66, C.lava), (104, 50, C.gold)]
    for (x, hgt, col) in jars {
        let r = R(x - 16, 108 - hgt, 32, hgt)
        let glass = drawJarGlass(r)
        clipped(glass) { linearFill(CGPath(rect: R(r.minX, r.minY + hgt * 0.45, 32, hgt), transform: nil), [col.lighter(0.3), col.darker(0.2)], P(0, r.minY + hgt * 0.45), P(0, r.maxY)) }
        fill(glass, Col(1, 1, 1, 0.08))
        stroke(glass, C.outline, 1.4)
        line(P(r.minX + 6, r.minY + hgt * 0.45), P(r.minX + 6, r.maxY - 8), Col(1, 1, 1, 0.5), 1.4)
        outlined(rr(R(x - 7, r.minY - 6, 14, 8), 2), C.woodLight, width: 1.2)
    }
    finish("item_shelf")
}

func lanternShape(_ cx: CGFloat, _ top: CGFloat, _ scale: CGFloat, glowCol: Col) {
    let w = 30 * scale, h = 44 * scale
    glow(P(cx, top + h * 0.55), 40 * scale, glowCol.alpha(0.6))
    outlined(circle(P(cx, top - 3 * scale), 4 * scale), C.iron, width: 1.2)
    let cap = poly([P(cx - w * 0.5, top + 8 * scale), P(cx + w * 0.5, top + 8 * scale), P(cx + w * 0.3, top), P(cx - w * 0.3, top)])
    outlinedGradient(cap, [C.copperLight, C.copperDark], P(0, top), P(0, top + 8 * scale), width: 1.2)
    let glass = rr(R(cx - w * 0.42, top + 8 * scale, w * 0.84, h - 16 * scale), 3 * scale)
    fill(glass, glowCol.lighter(0.4)); stroke(glass, C.outline, 1.2)
    glow(P(cx, top + h * 0.5), 10 * scale, C.cream)
    for dx in [-w * 0.42, 0, w * 0.42] { line(P(cx + dx, top + 8 * scale), P(cx + dx, top + h - 8 * scale), C.iron, 1.4) }
    outlinedGradient(rr(R(cx - w * 0.5, top + h - 8 * scale, w, 8 * scale), 2), [C.copper, C.copperDark], P(0, top + h - 8 * scale), P(0, top + h), width: 1.2)
}

func drawLanternsItem() {
    beginPt(140, 140)
    let rod = rr(R(8, 16, 124, 7), 3)
    outlinedGradient(rod, [C.woodLight, C.woodDark], P(0, 16), P(0, 23))
    for (x, drop, col) in [(CGFloat(30), CGFloat(24), C.lavaHot), (70, 40, C.patinaLight), (110, 28, C.goldLight)] {
        line(P(x, 22), P(x, 22 + drop), C.iron, 1.4)
        lanternShape(x, 22 + drop + 4, 1, glowCol: col)
    }
    finish("item_lanterns")
}

func drawCoreItem() {
    beginPt(140, 140)
    glow(P(70, 70), 70, Col(hex: 0xFFB45A, 0.25))
    let stand = rr(R(40, 118, 60, 12), 3)
    outlinedGradient(stand, [C.copperLight, C.copperDark], P(0, 118), P(0, 130))
    let tube = rr(R(52, 12, 36, 108), 8)
    clipped(tube) {
        let layers: [Col] = [Col(hex: 0x8D6B57), Col(hex: 0x5A4440), Col(hex: 0xB78A52), Col(hex: 0x3B3036), Col(hex: 0x9F5B3A), Col(hex: 0x6E6A66), Col(hex: 0xC9A15A), Col(hex: 0x4A3A3C)]
        var y: CGFloat = 12
        var g = Rng(s: 6)
        for (i, c) in layers.enumerated() {
            let hgt = g.r(9, 18)
            fill(CGPath(rect: R(52, y, 36, hgt), transform: nil), c)
            if i % 3 == 1 { fill(circle(P(g.r(58, 82), y + hgt / 2), 2), C.goldLight) }
            y += hgt
        }
        fill(R(54, 12, 6, 108), Col(1, 1, 1, 0.18))
    }
    stroke(tube, C.outline, 1.6)
    for y in [CGFloat(20), 112] { outlined(rr(R(48, y - 4, 44, 8), 3), C.copper, width: 1.2) }
    finish("item_core")
}

func drawBoardItem() {
    beginPt(140, 140)
    let frame = rr(R(10, 14, 120, 100), 6)
    outlinedGradient(frame, [C.woodLight, C.woodDark], P(0, 14), P(0, 114))
    let cork = rr(R(18, 22, 104, 84), 3)
    fill(cork, Col(hex: 0xB98A5A))
    clipped(cork) { var g = Rng(s: 9); for _ in 0..<160 { fill(circle(P(g.r(18, 122), g.r(22, 106)), 0.7), Col(hex: 0x7A5432, 0.6)) } }
    stroke(cork, C.outline, 1.2)
    let notes: [(CGRect, CGFloat, Col)] = [(R(26, 30, 40, 34), -0.08, C.paper), (R(72, 28, 42, 30), 0.06, C.cream), (R(40, 66, 56, 34), 0.03, C.paper)]
    for (r, rot, col) in notes {
        ctx.saveGState(); ctx.translateBy(x: r.midX, y: r.midY); ctx.rotate(by: rot)
        let n = CGRect(x: -r.width / 2, y: -r.height / 2, width: r.width, height: r.height)
        softShadow(CGPath(rect: n, transform: nil), dy: 1.5, blur: 2, alpha: 0.4)
        outlined(CGPath(rect: n, transform: nil), col, width: 1)
        for i in 0..<3 { line(P(n.minX + 5, n.minY + 10 + CGFloat(i) * 7), P(n.maxX - 6, n.minY + 10 + CGFloat(i) * 7), C.inkLine, 1) }
        outlined(circle(P(0, n.minY + 3), 3), C.lava, width: 0.8)
        ctx.restoreGState()
    }
    // Stand legs.
    for x in [CGFloat(30), 110] { outlined(rr(R(x - 4, 112, 8, 22), 2), C.woodDark, width: 1.2) }
    finish("item_board")
}

extension C { static let inkLine = Col(hex: 0x5C4636, 0.7) }

func valveWheel(_ c: CGPoint, _ r: CGFloat, col: Col) {
    let ring = CGMutablePath()
    ring.addEllipse(in: R(c.x - r, c.y - r, r * 2, r * 2))
    ring.addEllipse(in: R(c.x - r * 0.78, c.y - r * 0.78, r * 1.56, r * 1.56))
    ctx.saveGState(); ctx.addPath(ring); ctx.clip(using: .evenOdd)
    linearFill(CGPath(rect: R(c.x - r, c.y - r, r * 2, r * 2), transform: nil), [col.lighter(0.35), col, col.darker(0.35)], P(c.x - r, c.y - r), P(c.x + r, c.y + r))
    ctx.restoreGState()
    stroke(circle(c, r), C.outline, 1.4); stroke(circle(c, r * 0.78), C.outline, 1.2)
    for i in 0..<4 {
        let a = CGFloat(i) * .pi / 4 + .pi / 8
        let p = CGMutablePath()
        p.move(to: P(c.x + cos(a) * r * 0.8, c.y + sin(a) * r * 0.8)); p.addLine(to: P(c.x - cos(a) * r * 0.8, c.y - sin(a) * r * 0.8))
        stroke(p, C.outline, r * 0.2 + 1.4); stroke(p, col, r * 0.2)
    }
    outlinedGradient(circle(c, r * 0.24), [col.lighter(0.4), col.darker(0.3)], P(c.x - r * 0.24, c.y - r * 0.24), P(c.x + r * 0.24, c.y + r * 0.24), width: 1.2)
}

func drawValveItem() {
    beginPt(60, 60)
    valveWheel(P(30, 30), 26, col: C.copper)
    finish("item_valve")
    beginPt(52, 52)
    valveWheel(P(26, 26), 22, col: Col(hex: 0xC4553A))
    finish("valve_close")
}

func drawLiftItem() {
    beginPt(200, 170)
    glow(P(100, 100), 110, Col(hex: 0xFFB45A, 0.3))
    // Cable.
    line(P(100, 0), P(100, 26), C.outline, 3.4); line(P(100, 0), P(100, 26), C.ironLight, 1.6)
    let roof = poly([P(28, 44), P(172, 44), P(150, 24), P(50, 24)])
    outlinedGradient(roof, [C.copperLight, C.copper, C.copperDark], P(0, 24), P(0, 44), width: 2)
    fill(R(52, 28, 96, 3), C.patinaLight.alpha(0.55))
    let cage = rr(R(34, 44, 132, 118), 4)
    fill(cage, Col(hex: 0x1A1418, 0.55))
    clipped(cage) { glow(P(100, 110), 70, Col(hex: 0xFFC27A, 0.35)) }
    for x in stride(from: CGFloat(34), through: 166, by: 16.5) { line(P(x, 44), P(x, 162), C.outline, 3.4); line(P(x, 44), P(x, 162), C.iron, 1.8) }
    for y in [CGFloat(44), 100, 162] { let b = rr(R(30, y - 4, 140, 8), 2); outlinedGradient(b, [C.ironLight, C.iron], P(0, y - 4), P(0, y + 4), width: 1.4) }
    for x in [CGFloat(36), 164] { rivet(P(x, 100), 2.4); rivet(P(x, 162), 2.4) }
    finish("item_lift")
}

// MARK: - Keepers

func eye(_ c: CGPoint, _ r: CGFloat, iris: Col = C.outline) {
    outlined(circle(c, r), C.cream, width: 1.2)
    fill(circle(P(c.x + r * 0.15, c.y + r * 0.1), r * 0.62), iris)
    fill(circle(P(c.x + r * 0.15, c.y + r * 0.1), r * 0.32), C.outline)
    fill(circle(P(c.x - r * 0.15, c.y - r * 0.3), r * 0.24), Col(1, 1, 1, 0.95))
}
func blush(_ c: CGPoint) { fill(ellipse(R(c.x - 9, c.y - 4, 18, 8)), Col(hex: 0xFF8A80, 0.45)) }
func smile(_ c: CGPoint, _ w: CGFloat) {
    let p = CGMutablePath(); p.move(to: P(c.x - w / 2, c.y)); p.addQuadCurve(to: P(c.x + w / 2, c.y), control: P(c.x, c.y + w * 0.45))
    stroke(p, C.outline, 2.2)
}

func keeperCanvas(_ name: String, _ body: () -> Void) {
    beginPt(200, 200)
    body()
    finish("keeper_\(name)")
}

func drawKeepers() {
    keeperCanvas("pip") {
        // Tunnel mole in a miner's helmet.
        let torso = ellipse(R(36, 120, 128, 110))
        outlinedGradient(torso, [Col(hex: 0x8A6A5A), Col(hex: 0x5B4136)], P(0, 120), P(0, 200), width: 2)
        let head = ellipse(R(44, 52, 112, 104))
        outlinedGradient(head, [Col(hex: 0x9C7A68), Col(hex: 0x6B4E40)], P(60, 52), P(140, 156), width: 2)
        fill(ellipse(R(70, 104, 60, 44)), Col(hex: 0xD9B8A0))
        stroke(ellipse(R(70, 104, 60, 44)), C.outline, 1.4)
        outlined(ellipse(R(88, 104, 24, 16)), Col(hex: 0xF08A9A), width: 1.6)
        eye(P(78, 96), 7); eye(P(122, 96), 7)
        smile(P(100, 132), 16)
        blush(P(66, 118)); blush(P(134, 118))
        let helmet = CGMutablePath()
        helmet.move(to: P(40, 82)); helmet.addCurve(to: P(160, 82), control1: P(44, 22), control2: P(156, 22)); helmet.closeSubpath()
        outlinedGradient(helmet, [C.goldLight, C.gold, C.goldDark], P(0, 30), P(0, 82), width: 2)
        outlined(rr(R(32, 76, 136, 12), 6), C.goldDark, width: 1.8)
        glow(P(100, 52), 30, C.cream)
        outlined(circle(P(100, 52), 11), C.cream, width: 1.6)
        for x in [CGFloat(52), 148] { outlined(ellipse(R(x - 14, 178, 28, 18)), Col(hex: 0xD9B8A0), width: 1.6) }
    }
    keeperCanvas("cinder") {
        // Fire salamander.
        let tail = CGMutablePath(); tail.move(to: P(150, 190)); tail.addCurve(to: P(196, 120), control1: P(190, 190), control2: P(200, 150))
        stroke(tail, C.outline, 16); stroke(tail, Col(hex: 0xE2552C), 12)
        let torso = ellipse(R(44, 120, 116, 100))
        outlinedGradient(torso, [Col(hex: 0xF07A3A), Col(hex: 0xB63A1E)], P(0, 120), P(0, 200), width: 2)
        let head = ellipse(R(34, 50, 132, 96))
        outlinedGradient(head, [Col(hex: 0xFF9A4A), Col(hex: 0xD2482A)], P(60, 50), P(140, 146), width: 2)
        for (x, y, r) in [(CGFloat(58), CGFloat(70), CGFloat(8)), (140, 74, 7), (100, 58, 6), (74, 128, 6), (128, 136, 8), (100, 170, 7)] {
            outlined(circle(P(x, y), r), C.lavaHot, width: 1.2)
        }
        eye(P(72, 92), 13, iris: Col(hex: 0x3A1A0A)); eye(P(128, 92), 13, iris: Col(hex: 0x3A1A0A))
        smile(P(100, 122), 34)
        blush(P(60, 118)); blush(P(140, 118))
    }
    keeperCanvas("basalt") {
        // Stone golem with lava cracks and patina eyes.
        let torso = rockShape(R(30, 120, 140, 110), seed: 3, points: 10, jitter: 0.08)
        outlinedGradient(torso, [C.rockLight, C.rock], P(0, 120), P(0, 200), width: 2)
        let head = rr(R(46, 40, 108, 96), 18)
        outlinedGradient(head, [Col(hex: 0x7A6A66), C.rockMid], P(60, 40), P(140, 136), width: 2)
        let crack = CGMutablePath(); crack.move(to: P(64, 44)); crack.addLine(to: P(76, 66)); crack.addLine(to: P(68, 82)); crack.addLine(to: P(80, 100))
        stroke(crack, C.lava, 2.4); glow(P(74, 76), 14, C.lava.alpha(0.6))
        let crack2 = CGMutablePath(); crack2.move(to: P(150, 150)); crack2.addLine(to: P(130, 168)); crack2.addLine(to: P(138, 188))
        stroke(crack2, C.lava, 2.4)
        let brow = rr(R(58, 74, 84, 10), 4); outlined(brow, C.rock, width: 1.4)
        for x in [CGFloat(80), 120] { glow(P(x, 94), 14, C.patinaLight); outlined(rr(R(x - 9, 89, 18, 10), 4), C.patinaLight, width: 1.2) }
        let mouth = rr(R(84, 114, 32, 6), 3); fill(mouth, C.outline)
        outlined(circle(P(142, 52), 9), C.patina, width: 1.2)
    }
    keeperCanvas("ash") {
        // Cave owl.
        let body = ellipse(R(40, 60, 120, 150))
        outlinedGradient(body, [Col(hex: 0xB7B0AA), Col(hex: 0x6E6660)], P(0, 60), P(0, 210), width: 2)
        for (x, side) in [(CGFloat(56), CGFloat(-1)), (144, 1)] {
            outlined(poly([P(x, 70), P(x + side * 14, 34), P(x - side * 16, 62)]), Col(hex: 0x8C847E), width: 1.8)
        }
        let face = CGMutablePath(); face.addEllipse(in: R(50, 70, 52, 56)); face.addEllipse(in: R(98, 70, 52, 56))
        fill(face, Col(hex: 0xE8E2D8)); stroke(face, C.outline, 1.6)
        eye(P(76, 98), 17, iris: Col(hex: 0xF0A020)); eye(P(124, 98), 17, iris: Col(hex: 0xF0A020))
        outlined(poly([P(92, 118), P(108, 118), P(100, 134)]), C.gold, width: 1.4)
        var g = Rng(s: 12)
        for _ in 0..<16 { let c = P(g.r(64, 136), g.r(146, 196)); let v = CGMutablePath(); v.move(to: P(c.x - 5, c.y)); v.addQuadCurve(to: P(c.x + 5, c.y), control: P(c.x, c.y + 6)); stroke(v, Col(hex: 0x4E4642), 1.4) }
    }
    keeperCanvas("ember") {
        // Lava fox with flame-tipped ears.
        for (x, side) in [(CGFloat(62), CGFloat(-1)), (138, 1)] {
            let ear = poly([P(x - side * 22, 84), P(x + side * 10, 16), P(x + side * 26, 84)])
            outlinedGradient(ear, [C.lavaHot, Col(hex: 0xE2602A)], P(0, 16), P(0, 84), width: 2)
            fill(poly([P(x - side * 8, 78), P(x + side * 8, 34), P(x + side * 16, 78)]), Col(hex: 0x5A2A1A))
            glow(P(x + side * 10, 22), 14, C.lavaHot)
        }
        let torso = ellipse(R(44, 130, 112, 90))
        outlinedGradient(torso, [Col(hex: 0xF0803A), Col(hex: 0xB8461E)], P(0, 130), P(0, 210), width: 2)
        fill(ellipse(R(74, 140, 52, 60)), C.cream)
        let head = CGMutablePath()
        head.move(to: P(36, 86)); head.addQuadCurve(to: P(164, 86), control: P(100, 40))
        head.addQuadCurve(to: P(100, 156), control: P(160, 140)); head.addQuadCurve(to: P(36, 86), control: P(40, 140)); head.closeSubpath()
        outlinedGradient(head, [Col(hex: 0xFF9248), Col(hex: 0xD55A26)], P(0, 50), P(0, 156), width: 2)
        let muzzle = CGMutablePath(); muzzle.move(to: P(64, 112)); muzzle.addQuadCurve(to: P(136, 112), control: P(100, 96)); muzzle.addQuadCurve(to: P(100, 154), control: P(132, 146)); muzzle.addQuadCurve(to: P(64, 112), control: P(68, 146)); muzzle.closeSubpath()
        fill(muzzle, C.cream); stroke(muzzle, C.outline, 1.2)
        outlined(ellipse(R(92, 132, 16, 11)), C.outline, width: 1)
        eye(P(76, 100), 9, iris: Col(hex: 0x2A6A40)); eye(P(124, 100), 9, iris: Col(hex: 0x2A6A40))
        blush(P(62, 124)); blush(P(138, 124))
    }
    keeperCanvas("hermit") {
        // Hermit crab in a copper spiral shell.
        let shell = circle(P(118, 112), 70)
        outlinedGradient(shell, [C.copperLight, C.copper, C.copperDark], P(60, 50), P(180, 180), width: 2.2)
        let spiral = CGMutablePath()
        var a: CGFloat = 0; var r: CGFloat = 4
        spiral.move(to: P(118, 112))
        while r < 62 { a += 0.2; r += 0.85; spiral.addLine(to: P(118 + cos(a) * r, 112 + sin(a) * r)) }
        stroke(spiral, C.copperDark, 3)
        fill(circle(P(96, 80), 10), C.patina.alpha(0.6)); fill(circle(P(150, 150), 8), C.patina.alpha(0.5))
        let crab = ellipse(R(20, 120, 110, 70))
        outlinedGradient(crab, [Col(hex: 0xF0644A), Col(hex: 0xB83224)], P(0, 120), P(0, 190), width: 2)
        for (x, top) in [(CGFloat(52), CGFloat(70)), (94, 66)] {
            line(P(x, 128), P(x, top + 10), C.outline, 5); line(P(x, 128), P(x, top + 10), Col(hex: 0xE2553A), 3)
            eye(P(x, top), 11)
        }
        for (x, y) in [(CGFloat(18), CGFloat(150)), (128, 172)] {
            let claw = CGMutablePath(); claw.addEllipse(in: R(x - 16, y - 12, 32, 24))
            outlined(claw, Col(hex: 0xE2553A), width: 1.8)
            line(P(x - 2, y - 12), P(x + 6, y + 2), C.outline, 2)
        }
        smile(P(72, 160), 18)
    }
}

// MARK: - Assay jars

func jarRect() -> CGRect { R(14, 22, 92, 120) }

func drawJars() {
    // Mask of the interior that the SwiftUI melt fill is clipped to.
    beginPt(120, 150)
    fill(drawJarGlass(jarRect().insetBy(dx: 4, dy: 4)), Col(1, 1, 1))
    finish("jar_mask")

    let objects: [String: () -> Void] = [
        "bellows": {
            let b = poly([P(40, 74), P(80, 74), P(72, 112), P(48, 112)])
            outlinedGradient(b, [C.woodLight, C.woodDark], P(0, 74), P(0, 112))
            for y in [CGFloat(84), 94, 104] { line(P(46, y), P(74, y), C.woodDark, 1.2) }
            outlined(rr(R(56, 112, 8, 14), 2), C.copper, width: 1.2)
            outlined(rr(R(52, 62, 16, 14), 3), C.copper, width: 1.2)
        },
        "counterweight": {
            let w = poly([P(44, 88), P(76, 88), P(86, 124), P(34, 124)])
            outlinedGradient(w, [C.ironLight, C.iron], P(0, 88), P(0, 124))
            stroke(circle(P(60, 80), 9), C.outline, 4.4); stroke(circle(P(60, 80), 9), C.ironLight, 2.4)
            label("5", P(60, 108), size: 14, color: C.cream)
        },
        "lavaSink": {
            for i in 0..<3 {
                let r = 26 - CGFloat(i) * 8
                stroke(ellipse(R(60 - r, 100 - r * 0.45, r * 2, r * 0.9)), [C.lavaHot, C.lava, C.lavaDeep][i], 3)
            }
            fill(ellipse(R(54, 97, 12, 6)), C.outline)
        },
        "assayLens": {
            stroke(circle(P(56, 92), 18), C.outline, 7); stroke(circle(P(56, 92), 18), C.copper, 4.4)
            fill(circle(P(56, 92), 15.5), C.patinaLight.alpha(0.45))
            fill(circle(P(50, 86), 5), Col(1, 1, 1, 0.7))
            line(P(69, 105), P(84, 122), C.outline, 8); line(P(69, 105), P(84, 122), C.woodLight, 5)
        },
        "spiritLevel": {
            let bar = rr(R(30, 92, 60, 20), 6)
            outlinedGradient(bar, [C.copperLight, C.copperDark], P(0, 92), P(0, 112))
            let vial = rr(R(40, 97, 40, 10), 5)
            fill(vial, C.patinaLight); stroke(vial, C.outline, 1.2)
            fill(ellipse(R(55, 98, 10, 6)), C.cream)
            line(P(52, 97), P(52, 107), C.outline, 1); line(P(68, 97), P(68, 107), C.outline, 1)
        }
    ]
    for (name, draw) in objects {
        beginPt(120, 150)
        let glass = drawJarGlass(jarRect())
        softShadow(glass, dy: 3, blur: 5, alpha: 0.3)
        ctx.setBlendMode(.clear); fill(glass, Col(0, 0, 0, 1)); ctx.setBlendMode(.normal)
        fill(glass, Col(hex: 0xBFE8E0, 0.12))
        draw()
        // Glass highlights and outline.
        line(P(24, 76), P(24, 128), Col(1, 1, 1, 0.55), 3)
        line(P(30, 60), P(36, 52), Col(1, 1, 1, 0.45), 2)
        stroke(glass, C.outline, 2)
        stroke(drawJarGlass(jarRect().insetBy(dx: 2, dy: 2)), Col(1, 1, 1, 0.25), 1)
        // Cork and label.
        let cork = rr(R(42, 12, 36, 16), 4)
        outlinedGradient(cork, [Col(hex: 0xC99A66), Col(hex: 0x8A6038)], P(0, 12), P(0, 28))
        line(P(44, 18), P(76, 18), Col(hex: 0x6A4426, 0.6), 1)
        finish("jar_\(name)")
    }
}

// MARK: - Icons, HUD and UI kit

func drawGoldIcon() {
    beginPt(40, 40)
    coinStackFront(20, 32, count: 3, w: 26, metal: "gold")
    fill(ellipse(R(9, 13, 6, 2.5)), Col(1, 1, 1, 0.7))
    finish("icon_gold")
}

func drawPlate() {
    beginPt(80, 40)
    let p = rr(R(1.5, 1.5, 77, 37), 9)
    outlinedGradient(p, [C.copperLight, C.copper, C.copperDark], P(0, 1.5), P(0, 38.5), width: 1.8)
    let inner = rr(R(6, 6, 68, 28), 6)
    linearFill(inner, [Col(hex: 0x2B1E1A), Col(hex: 0x1A1210)], P(0, 6), P(0, 34)); stroke(inner, C.copperDark, 1)
    finish("plate")
}

func drawMedallion() {
    beginPt(52, 52)
    let c = P(26, 26)
    outlinedGradient(circle(c, 24), [C.copperLight, C.copper, C.copperDark], P(4, 4), P(48, 48), width: 1.8)
    stroke(circle(c, 19), C.patina, 2.4)
    fill(circle(c, 17), Col(hex: 0x2A1C18))
    for i in 0..<8 { let a = CGFloat(i) * .pi / 4; rivet(P(26 + cos(a) * 21.5, 26 + sin(a) * 21.5), 1.2) }
    finish("medallion")
}

func drawPlaque() {
    beginPt(200, 50)
    let p = rr(R(2, 2, 196, 46), 8)
    outlinedGradient(p, [C.woodLight, C.wood, C.woodDark], P(0, 2), P(0, 48), width: 2)
    clipped(p) { var g = Rng(s: 19); for _ in 0..<8 { let y = g.r(6, 44); line(P(2, y), P(198, y + g.r(-2, 2)), C.woodDark.alpha(0.35), 0.7) } }
    for (x, y) in [(CGFloat(10), CGFloat(10)), (190, 10), (10, 40), (190, 40)] { rivet(P(x, y), 2.2) }
    finish("plaque")
}

func drawShelfPlank() {
    beginPt(400, 30)
    let p = rr(R(0, 4, 400, 14), 3)
    outlinedGradient(p, [C.woodLight, C.wood, C.woodDark], P(0, 4), P(0, 18))
    clipped(p) { var g = Rng(s: 23); for _ in 0..<10 { let x = g.r(0, 400); line(P(x, 6), P(x + g.r(20, 60), 7), C.woodDark.alpha(0.4), 0.6) } }
    for x in [CGFloat(24), 376] { outlined(poly([P(x - 7, 18), P(x + 7, 18), P(x, 29)]), C.copper, width: 1.2) }
    finish("shelf_plank")
}

func drawLanternFrame() {
    beginPt(140, 200)
    glow(P(70, 110), 90, C.lavaHot.alpha(0.35))
    outlined(circle(P(70, 10), 7), C.iron, width: 1.6)
    fill(circle(P(70, 10), 3.5), Col(0, 0, 0, 0))
    let cap = poly([P(14, 44), P(126, 44), P(104, 18), P(36, 18)])
    outlinedGradient(cap, [C.copperLight, C.copper, C.copperDark], P(0, 18), P(0, 44), width: 2)
    fill(R(40, 22, 60, 3), C.patinaLight.alpha(0.5))
    let base = rr(R(10, 166, 120, 22), 5)
    outlinedGradient(base, [C.copper, C.copperDark], P(0, 166), P(0, 188), width: 2)
    // Window posts; the window itself stays transparent for the portrait behind.
    for x in [CGFloat(18), 122] {
        let post = rr(R(x - 6, 42, 12, 126), 3)
        outlinedGradient(post, [C.ironLight, C.iron], P(x - 6, 0), P(x + 6, 0), width: 1.6)
    }
    let window = R(24, 44, 92, 122)
    stroke(CGPath(rect: window, transform: nil), C.outline, 2)
    line(P(24, 52), P(116, 52), Col(1, 1, 1, 0.25), 2)
    for (x, y) in [(CGFloat(18), CGFloat(56)), (122, 56), (18, 154), (122, 154)] { rivet(P(x, y), 2) }
    finish("lantern_frame")
}

func drawTag() {
    beginPt(100, 40)
    let t = CGMutablePath()
    t.move(to: P(14, 2)); t.addLine(to: P(97, 2)); t.addLine(to: P(97, 38)); t.addLine(to: P(14, 38)); t.addLine(to: P(2, 20)); t.closeSubpath()
    outlinedGradient(t, [C.cream, C.paperShade], P(0, 2), P(0, 38), width: 1.4)
    outlined(circle(P(13, 20), 3.2), C.copper, width: 1)
    finish("tag_perk")
}

func drawDial() {
    beginPt(120, 70)
    let c = P(60, 64)
    let bezel = CGMutablePath(); bezel.addArc(center: c, radius: 58, startAngle: .pi, endAngle: 0, clockwise: false); bezel.closeSubpath()
    outlinedGradient(bezel, [C.copperLight, C.copper, C.copperDark], P(0, 6), P(0, 64), width: 1.8)
    let face = CGMutablePath(); face.addArc(center: c, radius: 50, startAngle: .pi, endAngle: 0, clockwise: false); face.closeSubpath()
    linearFill(face, [C.cream, C.paper], P(0, 14), P(0, 64)); stroke(face, C.copperDark, 1)
    for i in 0...12 {
        let a = .pi + CGFloat(i) / 12 * .pi
        let r0: CGFloat = i % 3 == 0 ? 38 : 43
        line(P(c.x + cos(a) * r0, c.y + sin(a) * r0), P(c.x + cos(a) * 48, c.y + sin(a) * 48), C.inkLine, i % 3 == 0 ? 1.6 : 1)
    }
    outlined(rr(R(4, 60, 112, 8), 3), C.copperDark, width: 1.2)
    finish("hud_dial")
    beginPt(10, 60)
    let needle = poly([P(5, 2), P(8, 50), P(5, 58), P(2, 50)])
    outlined(needle, C.lava, width: 1)
    outlined(circle(P(5, 52), 4), C.copperDark, width: 1)
    finish("hud_needle")
}

func drawThermo() {
    beginPt(40, 200)
    let tube = rr(R(12, 8, 16, 170), 8)
    fill(tube, Col(hex: 0x1A1210, 0.0))
    stroke(tube, C.outline, 3.4); stroke(tube, C.silverLight.alpha(0.55), 1.4)
    let bulb = circle(P(20, 182), 14)
    outlinedGradient(bulb, [C.lavaHot, C.lava, C.lavaDeep], P(10, 170), P(30, 196), width: 2)
    fill(circle(P(15, 177), 3.5), Col(1, 1, 1, 0.6))
    outlinedGradient(rr(R(8, 2, 24, 10), 4), [C.copperLight, C.copperDark], P(0, 2), P(0, 12), width: 1.4)
    line(P(16, 14), P(16, 168), Col(1, 1, 1, 0.35), 1.4)
    finish("hud_thermo")
}

func drawRuler() {
    beginPt(30, 200)
    let r = rr(R(4, 2, 22, 196), 5)
    outlinedGradient(r, [C.rockLight, C.rockMid, C.rock], P(4, 0), P(26, 0))
    for i in 0..<20 {
        let y = 8 + CGFloat(i) * 9.6
        line(P(i % 5 == 0 ? 8 : 15, y), P(24, y), C.outline.alpha(0.8), i % 5 == 0 ? 1.6 : 1)
    }
    finish("hud_ruler")
}

func drawMineCart() {
    beginPt(200, 140)
    glow(P(100, 50), 90, C.goldLight.alpha(0.5))
    // Heap of coins.
    var g = Rng(s: 51)
    for i in 0..<40 {
        let x = g.r(36, 164), y = g.r(28, 64) + abs(x - 100) * 0.25
        let m = ["gold", "gold", "copper", "silver"][i % 4]
        let (l, mid, _) = coinMetalCols(m)
        let e = ellipse(R(x - 10, y - 4, 20, 8))
        fill(e, mid); stroke(e, C.outline, 1); fill(ellipse(R(x - 6, y - 3, 10, 3)), l)
    }
    let ingot = poly([P(84, 30), P(116, 30), P(122, 42), P(78, 42)])
    outlinedGradient(ingot, [C.goldLight, C.goldDark], P(0, 30), P(0, 42), width: 1.4)
    let body = poly([P(22, 60), P(178, 60), P(162, 116), P(38, 116)])
    outlinedGradient(body, [C.ironLight, C.iron, Col(hex: 0x24272C)], P(0, 60), P(0, 116), width: 2.2)
    for y in [CGFloat(72), 104] { line(P(28, y), P(172, y), C.copper, 3) }
    for x in [CGFloat(50), 100, 150] { rivet(P(x, 72)); rivet(P(x, 104)) }
    for x in [CGFloat(62), 138] {
        outlinedGradient(circle(P(x, 120), 15), [C.ironLight, C.iron], P(x - 15, 105), P(x + 15, 135), width: 2)
        outlined(circle(P(x, 120), 5), C.copper, width: 1.2)
    }
    line(P(6, 136), P(194, 136), C.outline, 4); line(P(6, 136), P(194, 136), C.ironLight, 2)
    finish("mine_cart")
}

func drawCrystals() {
    let hues: [(Col, Col)] = [(Col(hex: 0xB58CFF), Col(hex: 0x5B3A9E)), (C.patinaLight, C.patinaDark), (C.lavaHot, Col(hex: 0xB0501A)),
                              (Col(hex: 0xFF7A8A), Col(hex: 0x9E2A3A)), (Col(hex: 0x8AC8FF), Col(hex: 0x2A5A9E)), (C.goldLight, C.goldDark)]
    func cluster(_ light: Col, _ dark: Col, locked: Bool) {
        let base = rockShape(R(14, 54, 52, 22), seed: 5, points: 10, jitter: 0.1)
        outlinedGradient(base, [C.rockLight, C.rock], P(0, 54), P(0, 76))
        let shards: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(40, 62, 13, 46), (26, 64, 9, 30), (54, 64, 9, 34), (34, 66, 7, 20)]
        for (x, y, w, h) in shards.reversed() {
            let s = poly([P(x - w / 2, y), P(x - w / 2, y - h + w * 0.6), P(x, y - h), P(x + w / 2, y - h + w * 0.6), P(x + w / 2, y)])
            if locked {
                outlined(s, Col(hex: 0x4A4044), width: 1.4)
            } else {
                outlinedGradient(s, [light, dark], P(x - w / 2, 0), P(x + w / 2, 0), width: 1.4)
                fill(poly([P(x - w / 2 + 1.5, y - 2), P(x - w / 2 + 1.5, y - h + w * 0.6), P(x - 1, y - h + 3), P(x - 1, y - 2)]), Col(1, 1, 1, 0.35))
            }
        }
        if !locked { glow(P(40, 30), 30, light.alpha(0.6)) }
    }
    for (i, (l, d)) in hues.enumerated() {
        beginPt(80, 80); cluster(l, d, locked: false); finish("crystal_\(i)")
    }
    beginPt(80, 80); cluster(C.rock, C.rock, locked: true); label("?", P(40, 44), size: 18, color: Col(hex: 0x8A7A74)); finish("crystal_locked")
}

// MARK: - Guide illustrations

func guideCanvas(_ name: String, _ draw: () -> Void) {
    beginPt(300, 200)
    let card = rr(R(0, 0, 300, 200), 16)
    clipped(card) {
        linearFill(CGPath(rect: R(0, 0, 300, 200), transform: nil), [Col(hex: 0x3A2A30), Col(hex: 0x1C1518), Col(hex: 0x3A1A10)], P(0, 0), P(0, 200), [0, 0.6, 1])
        glow(P(150, 230), 160, C.lava.alpha(0.35))
        draw()
    }
    finish(name)
}

func sideCoin(_ x: CGFloat, _ y: CGFloat, _ m: String, w: CGFloat = 54, t: CGFloat = 12, hot: CGFloat = 0) {
    let (l, mid, d) = coinMetalCols(m)
    let body = rr(R(x - w / 2, y - t / 2, w, t), t * 0.42)
    if hot > 0 { glow(P(x, y), w * 0.9, C.lavaHot.alpha(hot)) }
    linearFill(body, [l.mix(C.lavaHot, hot), mid.mix(C.lava, hot * 0.8), d.mix(C.lava, hot * 0.5)], P(0, y - t / 2), P(0, y + t / 2))
    stroke(body, C.outline, 1.3)
}

func miniBeam(_ cx: CGFloat, _ y: CGFloat, tilt: CGFloat = 0, width: CGFloat = 200) {
    ctx.saveGState(); ctx.translateBy(x: cx, y: y); ctx.rotate(by: tilt)
    let b = rr(R(-width / 2, -6, width, 12), 4)
    outlinedGradient(b, [C.rockLight, C.rockMid], P(0, -6), P(0, 6))
    for x in [-width / 2 + 8, 0, width / 2 - 8] { outlined(rr(R(x - 5, -8, 10, 16), 2), C.copper, width: 1.1) }
    ctx.restoreGState()
    outlinedGradient(poly([P(cx, y + 6), P(cx + 22, y + 46), P(cx - 22, y + 46)]), [C.rockLight, C.rock], P(cx, y), P(cx, y + 46))
}

func miniClaw(_ x: CGFloat, _ y: CGFloat) {
    line(P(x, 0), P(x, y - 10), C.outline, 3.6); line(P(x, 0), P(x, y - 10), C.ironLight, 1.8)
    outlinedGradient(rr(R(x - 16, y - 12, 32, 14), 4), [C.copperLight, C.copperDark], P(0, y - 12), P(0, y + 2), width: 1.3)
    for side in [CGFloat(-1), 1] {
        let p = CGMutablePath(); p.move(to: P(x + side * 8, y)); p.addQuadCurve(to: P(x + side * 26, y + 22), control: P(x + side * 26, y + 2))
        stroke(p, C.outline, 5); stroke(p, C.iron, 3)
    }
}

func arrowDown(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ c: Col) {
    line(P(x, y0), P(x, y1 - 8), c, 3)
    fill(poly([P(x - 7, y1 - 10), P(x + 7, y1 - 10), P(x, y1)]), c)
}

func drawGuides() {
    guideCanvas("guide_drop") {
        miniBeam(150, 152)
        sideCoin(120, 140, "copper"); sideCoin(124, 128, "silver", w: 46)
        miniClaw(176, 44)
        sideCoin(176, 74, "gold", w: 42, hot: 0.5)
        arrowDown(176, 86, 112, C.goldLight)
        // Finger drag hint.
        let finger = rr(R(220, 30, 26, 40), 13)
        outlined(finger, C.paper, width: 1.4)
        line(P(200, 50), P(214, 50), C.patinaLight, 2.4); fill(poly([P(198, 44), P(198, 56), P(190, 50)]), C.patinaLight)
    }
    guideCanvas("guide_weld") {
        miniBeam(150, 156)
        sideCoin(150, 144, "copper", w: 64)
        sideCoin(150, 131, "copper", w: 60, hot: 0.85)
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * .pi * 2
            line(P(150 + cos(a) * 34, 136 + sin(a) * 14), P(150 + cos(a) * 46, 136 + sin(a) * 20), C.lavaHot, 2)
        }
        // Heat bar with the weld band.
        let track = rr(R(60, 40, 180, 16), 8)
        fill(track, Col(0, 0, 0, 0.5)); stroke(track, C.paper.alpha(0.7), 1.2)
        fill(rr(R(168, 42, 70, 12), 6), C.goldLight.alpha(0.45))
        fill(rr(R(62, 44, 150, 8), 4), C.lavaHot)
        label("WELD", P(203, 72), size: 14, color: C.goldLight)
    }
    guideCanvas("guide_mint") {
        miniBeam(80, 160, width: 120)
        sideCoin(80, 148, "gold", w: 44); sideCoin(80, 136, "gold", w: 44); sideCoin(80, 124, "gold", w: 44)
        line(P(124, 120), P(176, 120), C.goldLight, 3); fill(poly([P(176, 112), P(176, 128), P(190, 120)]), C.goldLight)
        miniBeam(236, 160, width: 120)
        let ingot = poly([P(206, 138), P(266, 138), P(274, 154), P(198, 154)])
        glow(P(236, 146), 50, C.goldLight.alpha(0.6))
        outlinedGradient(ingot, [C.goldLight, C.gold, C.goldDark], P(0, 138), P(0, 154))
        label("x3", P(80, 96), size: 18, color: C.goldLight, outline: C.outline, outlineWidth: 3)
    }
    guideCanvas("guide_fulcrum") {
        miniBeam(150, 140, tilt: 0.16)
        sideCoin(206, 136, "obsidian", w: 50, t: 14)
        sideCoin(210, 122, "copper", w: 48)
        // Dial.
        let c = P(70, 70)
        let face = CGMutablePath(); face.addArc(center: c, radius: 40, startAngle: .pi, endAngle: 0, clockwise: false); face.closeSubpath()
        outlined(face, C.paper, width: 1.6)
        let zone = CGMutablePath(); zone.addArc(center: c, radius: 34, startAngle: -.pi / 2 - 0.25, endAngle: -.pi / 2 + 0.25, clockwise: false)
        stroke(zone, C.patina, 6)
        line(c, P(c.x + cos(-.pi / 2 + 0.7) * 34, c.y + sin(-.pi / 2 + 0.7) * 34), C.lava, 2.6)
        fill(circle(c, 4), C.copperDark)
    }
    guideCanvas("guide_lava") {
        // Lava rising in notches with a coin sinking.
        let lavaTop: CGFloat = 130
        let p = CGMutablePath(); p.move(to: P(0, lavaTop)); p.addQuadCurve(to: P(300, lavaTop), control: P(150, lavaTop - 12)); p.addLine(to: P(300, 200)); p.addLine(to: P(0, 200)); p.closeSubpath()
        linearFill(p, [C.lavaHot, C.lava, C.lavaDeep], P(0, lavaTop - 6), P(0, 200))
        miniBeam(150, 96, width: 170)
        sideCoin(236, 132, "silver", w: 40)
        for i in 0..<5 {
            let y = 180 - CGFloat(i) * 16
            line(P(16, y), P(34, y), C.paper, 2)
        }
        line(P(40, 176), P(40, 132), C.lavaHot, 3); fill(poly([P(33, 134), P(47, 134), P(40, 122)]), C.lavaHot)
    }
}

// MARK: - Run everything

drawCoinSide("copper", w: 86, t: 17)
drawCoinSide("silver", w: 72, t: 16)
drawCoinSide("gold", w: 58, t: 15)
drawCoinSide("obsidian", w: 96, t: 21)
for m in ["copper", "silver", "gold"] { drawIngot(m) }
drawBeam(); drawFulcrum(); drawClaw(); drawChain(); drawLavaCrust(); drawGlow()
drawShaft(); drawVault(); drawPaper(); drawSlate(); drawCoreRock()
drawLogo(); drawHubBalance(); drawShelfItem(); drawLanternsItem(); drawCoreItem(); drawBoardItem(); drawValveItem(); drawLiftItem()
drawKeepers(); drawJars()
drawGoldIcon(); drawPlate(); drawMedallion(); drawPlaque(); drawShelfPlank(); drawLanternFrame(); drawTag()
drawDial(); drawThermo(); drawRuler(); drawMineCart(); drawCrystals(); drawGuides()
print("done")
