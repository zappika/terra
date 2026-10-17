// Renders the plain v1 app icon: a white SF Symbol on system blue, opaque 1024 px.
// usage: swift scripts/icon-render.swift <out.png>
import AppKit

let size = 1024
let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

NSColor(srgbRed: 0, green: 0.478, blue: 1, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let symbol = NSImage(systemSymbolName: "location.north.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 440, weight: .semibold))!
let s = symbol.size
let rect = NSRect(x: (Double(size) - s.width) / 2, y: (Double(size) - s.height) / 2, width: s.width, height: s.height)
// Tint the template symbol white.
let tinted = NSImage(size: s, flipped: false) { r in
    symbol.draw(in: r)
    NSColor.white.set()
    r.fill(using: .sourceAtop)
    return true
}
tinted.draw(in: rect)

NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
