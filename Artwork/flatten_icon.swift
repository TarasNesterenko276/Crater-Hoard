import AppKit

let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "CraterHoard/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let url = URL(fileURLWithPath: path)
guard let src = NSImage(contentsOf: url) else {
    fputs("failed to load \(path)\n", stderr)
    exit(1)
}

let width = 1024
let height = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 23 / 255, green: 20 / 255, blue: 26 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let drawRect = NSRect(x: 0, y: 0, width: width, height: height)
src.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}
try data.write(to: url)
print("flattened \(path) bytes=\(data.count)")
