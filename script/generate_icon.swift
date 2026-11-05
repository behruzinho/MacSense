import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let inset = size * 0.08
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: rect, xRadius: size * 0.19, yRadius: size * 0.19)
    NSGradient(starting: NSColor(srgbRed: 0.30, green: 0.55, blue: 1, alpha: 1), ending: NSColor(srgbRed: 0.16, green: 0.25, blue: 0.65, alpha: 1))!.draw(in: shape, angle: -65)
    NSColor.white.withAlphaComponent(0.18).setStroke(); shape.lineWidth = max(1, size * 0.008); shape.stroke()
    let line = NSBezierPath()
    let points: [(CGFloat,CGFloat)] = [(0.22,0.5),(0.34,0.5),(0.41,0.68),(0.51,0.30),(0.60,0.59),(0.66,0.5),(0.79,0.5)]
    for (index, point) in points.enumerated() { let p = NSPoint(x: size * point.0, y: size * point.1); if index == 0 { line.move(to:p) } else { line.line(to:p) } }
    line.lineWidth = size * 0.045; line.lineJoinStyle = .round; line.lineCapStyle = .round
    NSColor.white.setStroke(); line.stroke()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name + ".png"))
}
