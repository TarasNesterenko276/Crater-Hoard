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

// MARK: - Scene parts

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

// MARK: - Slope: sky, volcano, terraces, rails, mine entrance

func drawSky() {
    let w: CGFloat = 430, h: CGFloat = 932
    beginPt(w, h)
    linearFill(CGPath(rect: R(0, 0, w, h), transform: nil),
               [Col(hex: 0x241A33), Col(hex: 0x5A2E45), Col(hex: 0xB0523A), Col(hex: 0x3A2226)], P(0, 0), P(0, h), [0, 0.35, 0.62, 1])
    var g = Rng(s: 41)
    for _ in 0..<60 { fill(circle(P(g.r(0, w), g.r(0, h * 0.3)), g.r(0.5, 1.3)), Col(1, 1, 1, g.r(0.3, 0.8))) }
    // Distant ridges.
    for (i, col) in [Col(hex: 0x4A2A34), Col(hex: 0x37202A)].enumerated() {
        let p = CGMutablePath()
        let base = h * (0.55 + CGFloat(i) * 0.07)
        p.move(to: P(0, h)); p.addLine(to: P(0, base))
        var x: CGFloat = 0
        while x < w { let nx = x + g.r(40, 90); p.addLine(to: P(nx, base - g.r(10, 60))); x = nx }
        p.addLine(to: P(w, h)); p.closeSubpath()
        fill(p, col)
    }
    finish("bg_sky")
}

/// The volcano: crater at the top centre of the artwork, slopes spreading to the edges.
func drawVolcano() {
    let w: CGFloat = 600, h: CGFloat = 520
    beginPt(w, h)
    let cone = CGMutablePath()
    cone.move(to: P(0, h)); cone.addLine(to: P(0, h * 0.92))
    cone.addCurve(to: P(w * 0.38, 26), control1: P(w * 0.16, h * 0.62), control2: P(w * 0.3, h * 0.2))
    cone.addQuadCurve(to: P(w * 0.62, 26), control: P(w * 0.5, 44))
    cone.addCurve(to: P(w, h * 0.92), control1: P(w * 0.7, h * 0.2), control2: P(w * 0.84, h * 0.62))
    cone.addLine(to: P(w, h)); cone.closeSubpath()
    softShadow(cone, dy: 0, blur: 14, alpha: 0.5)
    linearFill(cone, [C.rockLight, C.rockMid, C.rock, C.basalt], P(w * 0.3, 0), P(w * 0.7, h), [0, 0.3, 0.65, 1])
    clipped(cone) {
        var g = Rng(s: 52)
        // Old lava streaks and ridges.
        for i in 0..<9 {
            let x0 = w * (0.4 + CGFloat(i) * 0.025)
            let p = CGMutablePath(); p.move(to: P(x0, 40))
            p.addCurve(to: P(w * CGFloat(i) / 8, h), control1: P(x0 + g.r(-40, 40), h * 0.35), control2: P(w * CGFloat(i) / 8 + g.r(-60, 60), h * 0.7))
            stroke(p, (i % 3 == 0 ? C.lava.alpha(0.55) : Col(0, 0, 0, 0.22)), i % 3 == 0 ? 5 : 3)
        }
        for _ in 0..<160 { fill(circle(P(g.r(0, w), g.r(30, h)), g.r(0.6, 2)), Col(0, 0, 0, 0.2)) }
        // Warm rim light from the crater.
        radialFill(CGPath(rect: R(0, 0, w, h), transform: nil), [C.lavaHot.alpha(0.35), C.lava.alpha(0)], P(w / 2, 30), 220)
    }
    stroke(cone, C.outline, 2.4)
    // Crater mouth.
    let mouth = ellipse(R(w * 0.38, 14, w * 0.24, 30))
    linearFill(mouth, [C.lavaHot, C.lava, C.lavaDeep], P(0, 14), P(0, 44))
    glow(P(w / 2, 26), 90, C.lavaHot.alpha(0.6))
    stroke(mouth, C.outline, 2.4)
    finish("volcano")
}

func drawTerrace() {
    beginPt(300, 200)
    let top = CGMutablePath()
    top.move(to: P(0, 6)); top.addLine(to: P(300, 6)); top.addLine(to: P(300, 200)); top.addLine(to: P(0, 200)); top.closeSubpath()
    linearFill(top, [Col(hex: 0x5C4440), Col(hex: 0x3A2C2C), Col(hex: 0x2A2022)], P(0, 6), P(0, 200), [0, 0.3, 1])
    clipped(top) {
        var g = Rng(s: 61)
        for _ in 0..<120 { fill(circle(P(g.r(0, 300), g.r(10, 200)), g.r(0.6, 2.2)), Col(0, 0, 0, 0.2)) }
        fill(R(0, 6, 300, 8), Col(hex: 0x8A6A5A, 0.7))
    }
    line(P(0, 6), P(300, 6), C.outline, 2)
    finish("terrace")
}

func drawRailTrack() {
    beginPt(200, 22)
    for x in stride(from: CGFloat(6), to: 200, by: 18) {
        outlined(rr(R(x, 8, 10, 13), 2), C.wood, width: 1)
    }
    for y in [CGFloat(6), 14] {
        let rail = rr(R(0, y, 200, 4), 2)
        outlinedGradient(rail, [C.ironLight, C.iron], P(0, y), P(0, y + 4), width: 0.8)
    }
    finish("rail_track")
}

func drawMineEntrance() {
    beginPt(92, 86)
    let arch = CGMutablePath()
    arch.move(to: P(8, 86)); arch.addLine(to: P(8, 34)); arch.addQuadCurve(to: P(84, 34), control: P(46, -6)); arch.addLine(to: P(84, 86)); arch.closeSubpath()
    outlinedGradient(arch, [C.rockLight, C.rock], P(0, 0), P(0, 86), width: 2)
    let hole = CGMutablePath()
    hole.move(to: P(22, 86)); hole.addLine(to: P(22, 40)); hole.addQuadCurve(to: P(70, 40), control: P(46, 12)); hole.addLine(to: P(70, 86)); hole.closeSubpath()
    fill(hole, Col(hex: 0x0E0A0C)); glow(P(46, 70), 30, C.lavaHot.alpha(0.35))
    for x in [CGFloat(20), 72] { outlinedGradient(rr(R(x - 5, 30, 10, 56), 2), [C.woodLight, C.woodDark], P(x - 5, 0), P(x + 5, 0), width: 1.2) }
    outlinedGradient(rr(R(12, 24, 68, 10), 3), [C.woodLight, C.woodDark], P(0, 24), P(0, 34), width: 1.2)
    // Water trough at the entrance.
    let trough = rr(R(30, 64, 46, 18), 4)
    outlinedGradient(trough, [C.woodLight, C.wood], P(0, 64), P(0, 82), width: 1.4)
    fill(rr(R(33, 66, 40, 6), 3), Col(hex: 0x6FC6E8))
    fill(R(36, 67, 14, 2), Col(1, 1, 1, 0.6))
    finish("mine_entrance")
}

// MARK: - Cart, cargo, projectiles, crust, lightning, ash

func drawCart() {
    beginPt(86, 58)
    let body = poly([P(4, 8), P(82, 8), P(72, 44), P(14, 44)])
    outlinedGradient(body, [C.copperLight, C.copper, C.copperDark], P(0, 8), P(0, 44), width: 2)
    fill(R(10, 12, 66, 4), C.patinaLight.alpha(0.5))
    for y in [CGFloat(20), 34] { line(P(9, y), P(77, y), C.copperDark, 2) }
    for x in [CGFloat(22), 43, 64] { rivet(P(x, 27), 2) }
    outlined(rr(R(2, 4, 82, 7), 3), C.iron, width: 1.4)
    for x in [CGFloat(24), 62] {
        outlinedGradient(circle(P(x, 47), 10), [C.ironLight, C.iron], P(x - 10, 37), P(x + 10, 57), width: 1.8)
        outlined(circle(P(x, 47), 3.5), C.copper, width: 1)
    }
    finish("cart")
}

func drawCargo() {
    beginPt(66, 30)
    var g = Rng(s: 71)
    for i in 0..<16 {
        let x = g.r(8, 58), y = g.r(10, 26) - (1 - abs(x - 33) / 33) * 10
        let (l, m, _) = coinMetalCols(["gold", "gold", "copper", "silver"][i % 4])
        let e = ellipse(R(x - 8, y - 3, 16, 7))
        fill(e, m); stroke(e, C.outline, 0.9); fill(ellipse(R(x - 5, y - 2, 8, 2.5)), l)
    }
    glow(P(33, 14), 26, C.goldLight.alpha(0.5))
    finish("cart_cargo")
}

func drawFrontCoins() {
    for m in ["copper", "silver", "gold"] {
        beginPt(40, 40)
        let (l, mid, d) = coinMetalCols(m)
        outlinedGradient(circle(P(20, 21), 17), [d, d.darker(0.2)], P(0, 4), P(0, 38), width: 1.6)
        outlinedGradient(circle(P(20, 19), 17), [l, mid, d], P(8, 4), P(32, 36), width: 1.6)
        stroke(circle(P(20, 19), 11.5), d, 1.6)
        // Crater mark stamped on the face.
        fill(poly([P(13, 23), P(17, 15), P(19, 17), P(21, 17), P(23, 15), P(27, 23)]), d.alpha(0.8))
        fill(ellipse(R(11, 9, 8, 4)), Col(1, 1, 1, 0.55))
        finish("coin_front_\(m)")
    }
}

func drawCore() {
    beginPt(44, 44)
    glow(P(22, 22), 26, C.lavaHot)
    let shape = poly([P(22, 3), P(36, 11), P(40, 26), P(30, 40), P(14, 40), P(4, 26), P(8, 11)])
    outlinedGradient(shape, [C.lavaHot, C.lava, C.lavaDeep], P(10, 4), P(34, 40), width: 1.8)
    fill(poly([P(22, 3), P(36, 11), P(22, 18), P(8, 11)]), Col(1, 1, 1, 0.35))
    fill(circle(P(22, 24), 5), C.cream)
    finish("volcanic_core")
}

func drawBomb() {
    beginPt(44, 44)
    let rock = rockShape(R(4, 4, 36, 36), seed: 81, points: 11, jitter: 0.1)
    outlinedGradient(rock, [Col(hex: 0x4A3A3C), Col(hex: 0x1E1618)], P(8, 4), P(36, 40), width: 1.8)
    clipped(rock) {
        for (a, b) in [(P(10, 14), P(22, 24)), (P(22, 24), P(34, 16)), (P(22, 24), P(20, 38))] { line(a, b, C.lavaHot, 2.6) }
        glow(P(22, 24), 12, C.lava)
    }
    finish("lava_bomb")
}

func drawBoulder() {
    beginPt(50, 38)
    let rock = poly([P(4, 36), P(8, 16), P(18, 6), P(32, 4), P(44, 14), P(47, 36)])
    outlinedGradient(rock, [C.obsidianShine.mix(C.obsidian, 0.4), C.obsidian, Col(hex: 0x0B0912)], P(10, 4), P(40, 36), width: 1.8)
    fill(poly([P(18, 6), P(32, 4), P(26, 18)]), Col(1, 1, 1, 0.25))
    fill(poly([P(8, 16), P(18, 6), P(14, 24)]), Col(1, 1, 1, 0.12))
    line(P(26, 18), P(30, 34), Col(1, 1, 1, 0.15), 1)
    finish("boulder")
}

func drawLightning() {
    beginPt(54, 300)
    let bolt = poly([P(30, 0), P(14, 120), P(28, 120), P(10, 300), P(44, 150), P(28, 150), P(42, 0)])
    glow(P(27, 150), 60, Col(hex: 0x9EE0FF, 0.6))
    fill(bolt, Col(hex: 0xE8F8FF)); stroke(bolt, Col(hex: 0x6FC6E8), 2)
    finish("lightning_bolt")
}

func drawAshCloud() {
    beginPt(430, 300)
    var g = Rng(s: 91)
    for i in 0..<40 {
        let c = P(g.r(-20, 450), g.r(20, 200) + CGFloat(i % 4) * 10)
        fill(circle(c, g.r(30, 70)), Col(hex: 0x3A3438, g.r(0.18, 0.35)))
    }
    for _ in 0..<16 { fill(circle(P(g.r(0, 430), g.r(10, 160)), g.r(20, 40)), Col(hex: 0x56505A, 0.25)) }
    finish("ash_cloud")
}

func drawPlanks() {
    beginPt(20, 34)
    let plank = rr(R(3, 2, 14, 30), 3)
    outlinedGradient(plank, [C.woodLight, C.wood, C.woodDark], P(3, 0), P(17, 0), width: 1.3)
    for y in [CGFloat(8), 26] { rivet(P(10, y), 1.6) }
    finish("plank")
    beginPt(20, 34)
    let top = poly([P(3, 2), P(17, 2), P(17, 13), P(11, 17), P(3, 14)])
    let bottom = poly([P(3, 19), P(10, 22), P(17, 18), P(17, 32), P(3, 32)])
    for part in [top, bottom] { outlined(part, Col(hex: 0x4A3A30), width: 1.2) }
    finish("plank_broken")
}

func drawHubCart() {
    beginPt(200, 180)
    glow(P(100, 90), 110, Col(hex: 0xFFB45A, 0.35))
    // Rail section on a rock ledge.
    let ledge = poly([P(4, 150), P(196, 150), P(184, 178), P(16, 178)])
    outlinedGradient(ledge, [C.rockLight, C.rock], P(0, 150), P(0, 178))
    for x in stride(from: CGFloat(10), to: 190, by: 16) { outlined(rr(R(x, 138, 9, 12), 2), C.wood, width: 1) }
    for y in [CGFloat(136), 144] { outlinedGradient(rr(R(0, y, 200, 4), 2), [C.ironLight, C.iron], P(0, y), P(0, y + 4), width: 0.8) }
    // Cart heaped with coins.
    ctx.saveGState(); ctx.translateBy(x: 50, y: 66); ctx.scaleBy(x: 1.2, y: 1.2)
    var g = Rng(s: 72)
    for i in 0..<22 {
        let x = g.r(10, 76), y = g.r(0, 14) + abs(x - 43) * 0.25
        let (l, m, _) = coinMetalCols(["gold", "gold", "copper", "silver"][i % 4])
        let e = ellipse(R(x - 8, y - 3, 16, 7)); fill(e, m); stroke(e, C.outline, 0.9); fill(ellipse(R(x - 5, y - 2, 8, 2.5)), l)
    }
    let body = poly([P(4, 14), P(82, 14), P(72, 50), P(14, 50)])
    outlinedGradient(body, [C.copperLight, C.copper, C.copperDark], P(0, 14), P(0, 50), width: 2)
    for y in [CGFloat(26), 40] { line(P(9, y), P(77, y), C.copperDark, 2) }
    for x in [CGFloat(24), 62] {
        outlinedGradient(circle(P(x, 53), 10), [C.ironLight, C.iron], P(x - 10, 43), P(x + 10, 63), width: 1.8)
        outlined(circle(P(x, 53), 3.5), C.copper, width: 1)
    }
    ctx.restoreGState()
    for _ in 0..<10 { glow(P(g.r(30, 170), g.r(20, 70)), g.r(2, 4), C.goldLight) }
    finish("hub_cart")
}

// MARK: - Upgrade jars for the cart and mine

func drawSlopeJars() {
    beginPt(120, 150)
    fill(drawJarGlass(jarRect().insetBy(dx: 4, dy: 4)), Col(1, 1, 1))
    finish("jar_mask")

    let objects: [String: () -> Void] = [
        "wheels": {
            outlinedGradient(circle(P(60, 98), 22), [C.ironLight, C.iron], P(38, 76), P(82, 120), width: 2)
            for i in 0..<6 { let a = CGFloat(i) * .pi / 3; line(P(60, 98), P(60 + cos(a) * 18, 98 + sin(a) * 18), C.ironLight, 2.4) }
            outlined(circle(P(60, 98), 6), C.copper, width: 1.2)
            fill(ellipse(R(66, 80, 10, 5)), C.goldLight.alpha(0.8))
        },
        "waterTank": {
            let tank = rr(R(38, 76, 44, 48), 10)
            outlinedGradient(tank, [C.copperLight, C.copperDark], P(38, 0), P(82, 0), width: 1.6)
            fill(rr(R(44, 92, 32, 26), 6), Col(hex: 0x6FC6E8))
            fill(R(48, 95, 12, 3), Col(1, 1, 1, 0.6))
            outlined(rr(R(52, 68, 16, 10), 3), C.iron, width: 1.2)
        },
        "ironPlating": {
            let plate = poly([P(40, 74), P(80, 74), P(84, 112), P(60, 126), P(36, 112)])
            outlinedGradient(plate, [C.ironLight, C.iron], P(40, 74), P(80, 126), width: 1.8)
            for (x, y) in [(CGFloat(46), CGFloat(82)), (74, 82), (46, 108), (74, 108)] { rivet(P(x, y), 2.2) }
        },
        "railSwitch": {
            for y in [CGFloat(110), 118] { outlinedGradient(rr(R(30, y, 60, 4), 2), [C.ironLight, C.iron], P(0, y), P(0, y + 4), width: 0.8) }
            line(P(60, 112), P(78, 76), C.outline, 6); line(P(60, 112), P(78, 76), C.woodLight, 3.6)
            outlined(circle(P(78, 76), 6), C.lava, width: 1.2)
            outlined(rr(R(52, 106, 16, 10), 3), C.copper, width: 1.2)
        },
        "sieve": {
            let rim = ellipse(R(32, 84, 56, 18))
            outlinedGradient(rim, [C.woodLight, C.woodDark], P(0, 84), P(0, 102), width: 1.6)
            let mesh = ellipse(R(36, 86, 48, 14))
            fill(mesh, C.iron.alpha(0.7))
            for x in stride(from: CGFloat(40), to: 82, by: 6) { line(P(x, 87), P(x, 99), C.ironLight.alpha(0.6), 0.8) }
            for (x, y) in [(CGFloat(48), CGFloat(80)), (60, 76), (72, 80)] {
                outlinedGradient(circle(P(x, y), 6), [C.goldLight, C.gold], P(x - 6, y - 6), P(x + 6, y + 6), width: 1)
            }
            for x in [CGFloat(52), 64] { fill(circle(P(x, 114), 2), C.goldLight) }
        }
    ]
    for (name, draw) in objects {
        beginPt(120, 150)
        let glass = drawJarGlass(jarRect())
        softShadow(glass, dy: 3, blur: 5, alpha: 0.3)
        ctx.setBlendMode(.clear); fill(glass, Col(0, 0, 0, 1)); ctx.setBlendMode(.normal)
        fill(glass, Col(hex: 0xBFE8E0, 0.12))
        draw()
        line(P(24, 76), P(24, 128), Col(1, 1, 1, 0.55), 3)
        line(P(30, 60), P(36, 52), Col(1, 1, 1, 0.45), 2)
        stroke(glass, C.outline, 2)
        stroke(drawJarGlass(jarRect().insetBy(dx: 2, dy: 2)), Col(1, 1, 1, 0.25), 1)
        let cork = rr(R(42, 12, 36, 16), 4)
        outlinedGradient(cork, [Col(hex: 0xC99A66), Col(hex: 0x8A6038)], P(0, 12), P(0, 28))
        line(P(44, 18), P(76, 18), Col(hex: 0x6A4426, 0.6), 1)
        finish("jar_\(name)")
    }
}

// MARK: - Guide illustrations

func guideCanvas(_ name: String, _ draw: () -> Void) {
    beginPt(300, 200)
    let card = rr(R(0, 0, 300, 200), 16)
    clipped(card) {
        linearFill(CGPath(rect: R(0, 0, 300, 200), transform: nil), [Col(hex: 0x3A2440), Col(hex: 0x8A3E3A), Col(hex: 0x2A1E22)], P(0, 0), P(0, 200), [0, 0.45, 1])
        draw()
    }
    finish(name)
}

func miniVolcano(_ glowCol: Col) {
    let cone = poly([P(80, 120), P(130, 30), P(170, 30), P(220, 120)])
    outlinedGradient(cone, [C.rockLight, C.rock], P(150, 30), P(150, 120))
    let mouth = ellipse(R(130, 24, 40, 12))
    fill(mouth, glowCol); stroke(mouth, C.outline, 1.6)
    glow(P(150, 28), 50, glowCol.alpha(0.7))
}

func miniRail(_ y: CGFloat, from x0: CGFloat = 20, to x1: CGFloat = 280) {
    fill(R(x0, y, x1 - x0, 40), Col(hex: 0x3A2C2C))
    line(P(x0, y), P(x1, y), C.outline, 1.6)
    for x in stride(from: x0 + 4, to: x1, by: 12) { fill(R(x, y - 5, 6, 6), C.wood) }
    line(P(x0, y - 5), P(x1, y - 5), C.ironLight, 2)
}

func miniCart(_ x: CGFloat, _ y: CGFloat, cargo: Bool = false, hot: CGFloat = 0) {
    if hot > 0 { glow(P(x, y - 12), 40, C.lava.alpha(hot)) }
    if cargo { for i in 0..<5 { fill(ellipse(R(x - 16 + CGFloat(i) * 6, y - 30 + CGFloat(i % 2) * 3, 10, 5)), C.gold) } }
    outlinedGradient(poly([P(x - 22, y - 26), P(x + 22, y - 26), P(x + 16, y - 6), P(x - 16, y - 6)]), [C.copperLight, C.copperDark], P(0, y - 26), P(0, y - 6), width: 1.4)
    for dx in [CGFloat(-10), 10] { outlined(circle(P(x + dx, y - 4), 5), C.iron, width: 1.2) }
}

func miniCoin(_ c: CGPoint, _ r: CGFloat = 7) {
    outlinedGradient(circle(c, r), [C.goldLight, C.gold], P(c.x - r, c.y - r), P(c.x + r, c.y + r), width: 1.2)
}

func miniBomb(_ c: CGPoint, _ r: CGFloat = 9) {
    outlined(circle(c, r), Col(hex: 0x2A2022), width: 1.4)
    line(P(c.x - r * 0.5, c.y - r * 0.2), P(c.x + r * 0.4, c.y + r * 0.3), C.lavaHot, 1.6)
    glow(c, r * 1.6, C.lava.alpha(0.6))
}

func drawSlopeGuides() {
    guideCanvas("guide_volley") {
        miniVolcano(C.goldLight)
        miniRail(160)
        for (x, a) in [(CGFloat(90), CGFloat(0.7)), (150, 0.45), (230, 0.6)] { fill(ellipse(R(x - 18, 152, 36, 8)), Col(0, 0, 0, a)) }
        miniCoin(P(110, 80)); miniCoin(P(190, 70)); miniBomb(P(150, 100))
        fill(ellipse(R(132, 152, 36, 8)), Col(hex: 0x6A0A00, 0.8))
        miniCart(90, 160)
    }
    guideCanvas("guide_cargo") {
        miniRail(150)
        miniCart(180, 150, cargo: true, hot: 0.7)
        // Mine entrance on the left with a water trough.
        let arch = CGMutablePath(); arch.move(to: P(20, 150)); arch.addLine(to: P(20, 96)); arch.addQuadCurve(to: P(80, 96), control: P(50, 66)); arch.addLine(to: P(80, 150)); arch.closeSubpath()
        outlined(arch, C.rockMid, width: 1.6)
        fill(rr(R(34, 104, 32, 46), 4), Col(hex: 0x0E0A0C))
        fill(rr(R(34, 132, 40, 10), 3), Col(hex: 0x6FC6E8))
        line(P(150, 120), P(96, 120), C.patinaLight, 3); fill(poly([P(96, 113), P(96, 127), P(86, 120)]), C.patinaLight)
        // Heat gauge.
        let tube = rr(R(254, 40, 14, 100), 7)
        fill(tube, Col(0, 0, 0, 0.5)); fill(rr(R(256, 64, 10, 74), 5), C.lava); stroke(tube, C.paper, 1.4)
        label("HEAT", P(261, 152), size: 11, color: C.paper)
    }
    guideCanvas("guide_crust") {
        miniRail(150)
        miniCart(90, 150)
        let boulder = poly([P(160, 150), P(164, 128), P(176, 118), P(192, 118), P(204, 132), P(206, 150)])
        outlinedGradient(boulder, [C.obsidianShine, C.obsidian], P(160, 118), P(206, 150))
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2
            line(P(183 + cos(a) * 30, 132 + sin(a) * 22), P(183 + cos(a) * 40, 132 + sin(a) * 30), C.goldLight, 2)
        }
        line(P(116, 130), P(150, 130), C.goldLight, 3); fill(poly([P(150, 123), P(150, 137), P(160, 130)]), C.goldLight)
        label("DASH", P(130, 112), size: 13, color: C.goldLight)
    }
    guideCanvas("guide_rails") {
        miniVolcano(C.lava)
        miniRail(118, from: 40, to: 260)
        miniRail(170)
        miniCart(110, 170)
        line(P(110, 150), P(110, 126), C.patinaLight, 3); fill(poly([P(103, 128), P(117, 128), P(110, 118)]), C.patinaLight)
        outlinedGradient(poly([P(200, 112), P(208, 98), P(216, 112)]), [C.lavaHot, C.lava], P(200, 98), P(216, 112))
        miniCoin(P(170, 100), 6); miniBomb(P(236, 94), 7)
        miniCoin(P(200, 154), 6)
    }
    guideCanvas("guide_ash") {
        for i in 0..<12 { fill(circle(P(20 + CGFloat(i) * 26, 40 + CGFloat(i % 3) * 8), 34), Col(hex: 0x2E282C, 0.7)) }
        miniRail(160)
        let bolt = poly([P(160, 40), P(146, 100), P(158, 100), P(144, 156), P(172, 92), P(160, 92), P(170, 40)])
        glow(P(158, 110), 40, Col(hex: 0x9EE0FF, 0.6))
        fill(bolt, Col(hex: 0xE8F8FF)); stroke(bolt, Col(hex: 0x6FC6E8), 1.4)
        fill(ellipse(R(130, 152, 56, 10)), Col(hex: 0x9EE0FF, 0.6))
        miniCart(158, 160, cargo: true)
        fill(ellipse(R(60, 152, 36, 8)), Col(0, 0, 0, 0.25))
    }
}

// MARK: - Run everything

drawGlow()
drawSky(); drawVolcano(); drawTerrace(); drawRailTrack(); drawMineEntrance()
drawCart(); drawCargo(); drawFrontCoins(); drawCore(); drawBomb(); drawBoulder(); drawLightning(); drawAshCloud(); drawPlanks()
drawVault(); drawPaper(); drawSlate(); drawCoreRock()
drawLogo(); drawHubCart(); drawShelfItem(); drawLanternsItem(); drawCoreItem(); drawBoardItem(); drawValveItem(); drawLiftItem()
drawKeepers(); drawSlopeJars()
drawGoldIcon(); drawPlate(); drawMedallion(); drawPlaque(); drawShelfPlank(); drawLanternFrame(); drawTag()
drawThermo(); drawMineCart(); drawCrystals(); drawSlopeGuides()
print("done")
