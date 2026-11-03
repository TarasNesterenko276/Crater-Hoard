// Crater Hoard sound generator.
// Synthesises every sound effect and the cave ambience loop as 16-bit mono WAV files.
// Deterministic: noise uses a fixed seed. Usage: swift generate_sounds.swift "<output dir>"

import Foundation

let rate = 44_100.0
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Sounds")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var noiseState: UInt64 = 0x1234_5678
func noise() -> Double {
    noiseState ^= noiseState << 13; noiseState ^= noiseState >> 7; noiseState ^= noiseState << 17
    return Double(noiseState % 20_000) / 10_000 - 1
}

struct Buffer {
    var s: [Double]
    init(_ seconds: Double) { s = Array(repeating: 0, count: Int(seconds * rate)) }
    var count: Int { s.count }
    mutating func add(_ other: Buffer, at t: Double, gain: Double = 1) {
        let o = Int(t * rate)
        for i in 0..<other.count where o + i < count && o + i >= 0 { s[o + i] += other.s[i] * gain }
    }
}

enum Wave { case sine, square, saw, triangle, noise }
func osc(_ w: Wave, _ phase: Double) -> Double {
    let p = phase - floor(phase)
    switch w {
    case .sine: return sin(p * 2 * .pi)
    case .square: return p < 0.5 ? 1 : -1
    case .saw: return 2 * p - 1
    case .triangle: return 4 * abs(p - 0.5) - 1
    case .noise: return noise()
    }
}

/// A tone whose frequency glides from f0 to f1, shaped by an attack/decay envelope.
func tone(_ w: Wave, _ f0: Double, _ f1: Double, _ dur: Double, attack: Double = 0.005, decay: Double? = nil, vibrato: Double = 0, vibRate: Double = 6, curve: Double = 1) -> Buffer {
    var b = Buffer(dur)
    var phase = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let k = pow(t / dur, curve)
        let f = f0 + (f1 - f0) * k + vibrato * sin(2 * .pi * vibRate * t)
        phase += f / rate
        let env: Double
        if t < attack { env = t / attack } else {
            let d = decay ?? (dur - attack)
            env = max(0, 1 - (t - attack) / d)
        }
        b.s[i] = osc(w, phase) * env * env
    }
    return b
}
func noiseBurst(_ dur: Double, attack: Double = 0.003, lowpass: Double = 1, highpass: Double = 0, curve: Double = 2) -> Buffer {
    var b = Buffer(dur)
    var lp = 0.0, hpPrev = 0.0, hpOut = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let env = t < attack ? t / attack : pow(max(0, 1 - (t - attack) / (dur - attack)), curve)
        let n = noise()
        lp += (n - lp) * lowpass
        hpOut = highpass > 0 ? highpass * (hpOut + lp - hpPrev) : lp
        hpPrev = lp
        b.s[i] = hpOut * env
    }
    return b
}
func lowpass(_ b: inout Buffer, _ a: Double) { var y = 0.0; for i in 0..<b.count { y += (b.s[i] - y) * a; b.s[i] = y } }

func write(_ name: String, _ b: Buffer, gain: Double = 0.8) {
    let peak = max(0.0001, b.s.map { abs($0) }.max() ?? 1)
    let scale = gain / peak
    var data = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    let bytes = UInt32(b.count * 2)
    data.append("RIFF".data(using: .ascii)!); u32(36 + bytes); data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
    data.append("data".data(using: .ascii)!); u32(bytes)
    for v in b.s { var x = Int16(max(-1, min(1, v * scale)) * 32_000).littleEndian; data.append(Data(bytes: &x, count: 2)) }
    try! data.write(to: outDir.appendingPathComponent("\(name).wav"))
}


/// A metallic "ting": a few inharmonic partials that ring out.
func clink(_ base: Double, _ dur: Double) -> Buffer {
    var b = Buffer(dur)
    for (ratio, gain) in [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12)] {
        b.add(tone(.sine, base * ratio, base * ratio * 0.995, dur, attack: 0.002, decay: dur * (1.1 - ratio / 12)), at: 0, gain: gain)
    }
    b.add(noiseBurst(0.02, lowpass: 0.6, highpass: 0.7), at: 0, gain: 0.4)
    return b
}

// MARK: - Effects

write("sfx_drop", { var b = tone(.triangle, 520, 260, 0.16, curve: 0.6); b.add(noiseBurst(0.08, lowpass: 0.3), at: 0, gain: 0.3); return b }(), gain: 0.5)
write("sfx_clink_0", clink(1180, 0.32), gain: 0.6)
write("sfx_clink_1", clink(1420, 0.30), gain: 0.6)
write("sfx_clink_2", clink(980, 0.36), gain: 0.6)
write("sfx_thud", { var b = tone(.sine, 140, 70, 0.22); b.add(noiseBurst(0.1, lowpass: 0.08), at: 0, gain: 0.8); return b }(), gain: 0.7)
write("sfx_weld", { var b = noiseBurst(0.45, attack: 0.01, lowpass: 0.9, highpass: 0.8, curve: 1.4); b.add(clink(1600, 0.25), at: 0, gain: 0.35); return b }(), gain: 0.55)
write("sfx_mint", {
    var b = Buffer(0.9)
    for (i, n) in [76, 80, 83, 88].enumerated() { b.add(clink(440 * pow(2, Double(n - 69) / 12) / 2, 0.6), at: Double(i) * 0.08, gain: 0.8) }
    b.add(tone(.sine, 90, 60, 0.4), at: 0, gain: 0.5)
    return b
}(), gain: 0.7)
write("sfx_spill", { var b = noiseBurst(0.7, attack: 0.02, lowpass: 0.25, curve: 1.2); b.add(tone(.sine, 300, 90, 0.5), at: 0, gain: 0.4); return b }(), gain: 0.6)
write("sfx_steady", tone(.triangle, 660, 990, 0.18, curve: 0.5), gain: 0.35)
write("sfx_tilt", { var b = tone(.square, 220, 180, 0.22); lowpass(&b, 0.15); return b }(), gain: 0.4)
write("sfx_count", clink(880, 0.18), gain: 0.4)
write("sfx_go", { var b = clink(1320, 0.4); b.add(clink(1760, 0.4), at: 0.06, gain: 0.7); return b }(), gain: 0.5)
write("sfx_tap", { var b = tone(.sine, 900, 700, 0.06); lowpass(&b, 0.5); return b }(), gain: 0.3)
write("sfx_buy", {
    var b = Buffer(0.6)
    for i in 0..<5 { b.add(clink(1000 + Double(i) * 140, 0.25), at: Double(i) * 0.05, gain: 0.7) }
    return b
}(), gain: 0.6)
write("sfx_gameover", {
    var b = Buffer(1.4)
    for (i, n) in [64, 60, 57, 52].enumerated() { b.add(tone(.triangle, midiHz(n), midiHz(n) * 0.98, 0.5, attack: 0.01), at: Double(i) * 0.22, gain: 0.7) }
    b.add(noiseBurst(1.2, attack: 0.2, lowpass: 0.1, curve: 1), at: 0.1, gain: 0.3)
    return b
}(), gain: 0.6)

func midiHz(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

// MARK: - Cave ambience loop: low lava rumble, slow bubbles and far drips.

do {
    let seconds = 12.0
    var b = Buffer(seconds)
    var rumble = noiseBurst(seconds, attack: 0.001, lowpass: 0.015, curve: 0.0001)
    lowpass(&rumble, 0.05)
    b.add(rumble, at: 0, gain: 2.2)
    let drone = tone(.sine, 55, 55, seconds, attack: 0.001, decay: seconds * 40, vibrato: 0.6, vibRate: 0.1)
    b.add(drone, at: 0, gain: 0.25)
    var bubbleSeed: UInt64 = 0xB0B
    for i in 0..<14 {
        bubbleSeed = bubbleSeed &* 6364136223846793005 &+ 1442695040888963407
        let t = Double(i) * 0.84 + Double(bubbleSeed >> 60) * 0.03
        let f = 120 + Double((bubbleSeed >> 52) & 0x3F)
        b.add(tone(.sine, f, f * 2.4, 0.12, attack: 0.01), at: t, gain: 0.25)
    }
    for t in [2.1, 6.7, 9.9] { b.add(clink(2100, 0.4), at: t, gain: 0.08) }
    // Crossfade the ends so the loop is seamless.
    let fade = Int(0.4 * rate)
    for i in 0..<fade {
        let k = Double(i) / Double(fade)
        b.s[i] *= k
        b.s[b.count - 1 - i] *= k
    }
    write("ambience_cave", b, gain: 0.5)
}
