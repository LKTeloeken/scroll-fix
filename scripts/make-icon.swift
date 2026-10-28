// Renders Resources/AppIcon.svg into Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let svg = root.appendingPathComponent("Resources/AppIcon.svg")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")

guard let image = NSImage(contentsOf: svg) else { fatalError("could not load \(svg.path)") }

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func writePNG(size: Int, name: String) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
}

for base in [16, 32, 128, 256, 512] {
    try writePNG(size: base, name: "icon_\(base)x\(base).png")
    try writePNG(size: base * 2, name: "icon_\(base)x\(base)@2x.png")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
// Smaller PNG for the README.
let png = root.appendingPathComponent("Resources/AppIcon.png")
try? FileManager.default.removeItem(at: png)
try FileManager.default.copyItem(at: iconset.appendingPathComponent("icon_256x256.png"), to: png)
print("wrote Resources/AppIcon.icns and Resources/AppIcon.png")
