// Rasterises a macOS app icon from any NSImage-readable source
// (.ai/.pdf/.png/.jpg).
//
//   fill — crop to a centred square, so the art reaches every edge
//   fit  — centre the art whole on a transparent canvas, cropping nothing
//
// Corners are masked with the macOS continuous-corner radius so the result
// looks like an app icon rather than a pasted screenshot.
import AppKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("usage: make-icon.swift <source> <out.png> [side] [fill|fit]")
}
let source = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let side = CGFloat(Double(args.count > 3 ? args[3] : "1024") ?? 1024)
let fills = (args.count > 4 ? args[4] : "fill") == "fill"
// macOS 26 applies its own icon shape and material. Supplying our own rounded
// mask (and the transparency it leaves behind) makes the system fall back to a
// desaturated rendering, so default to a full-bleed opaque square.
let rounds = ProcessInfo.processInfo.environment["ICON_ROUNDED"] == "1"

guard let image = NSImage(contentsOf: source), image.size.width > 0, image.size.height > 0 else {
    fail("cannot read \(source.path)")
}

// Fill crops the short edge away; fit letterboxes instead.
let scale = fills
    ? max(side / image.size.width, side / image.size.height)
    : min(side / image.size.width, side / image.size.height)
let drawn = NSSize(width: image.size.width * scale, height: image.size.height * scale)
let origin = NSPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fail("cannot allocate bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: side, height: side)
if rounds {
    NSBezierPath(roundedRect: canvas, xRadius: side * 0.2237, yRadius: side * 0.2237).addClip()
} else {
    // Opaque ground so the icon carries no alpha at all.
    NSColor.white.setFill()
    canvas.fill()
}
image.draw(in: NSRect(origin: origin, size: drawn))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fail("cannot encode png") }
try png.write(to: output)
print("master \(Int(side))x\(Int(side)) (\(fills ? "fill" : "fit")\(rounds ? ", rounded" : ", full-bleed")) from \(source.lastPathComponent)")
