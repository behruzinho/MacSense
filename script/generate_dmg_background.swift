import AppKit

// A 2× TIFF keeps Finder's background sharp on Retina displays.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let version = CommandLine.arguments[2]
let architecture = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "arm64"
let platform = architecture == "arm64" ? "Apple Silicon" : architecture == "x86_64" ? "Intel" : architecture
let width: CGFloat = 720
let height: CGFloat = 460
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440, pixelsHigh: 920,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: height - y - h, width: w, height: h)
}
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}
func text(_ value: String, x: CGFloat, y: CGFloat, w: CGFloat, size: CGFloat,
          weight: NSFont.Weight = .regular, tint: NSColor, centered: Bool = false) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    (value as NSString).draw(in: rect(x, y, w, size * 1.6), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: tint, .paragraphStyle: paragraph
    ])
}

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(starting: color(0.96, 0.97, 0.99), ending: color(0.89, 0.93, 0.99))!
    .draw(in: canvas, angle: -55)
let header = NSBezierPath(rect: rect(0, 0, width, 126))
NSGradient(starting: color(0.12, 0.14, 0.18), ending: color(0.12, 0.20, 0.34))!
    .draw(in: header, angle: 0)

let pulse = NSBezierPath()
let points: [(CGFloat, CGFloat)] = [(40, 58), (51, 58), (57, 39), (65, 77), (73, 49), (79, 58), (91, 58)]
for (index, p) in points.enumerated() {
    let point = NSPoint(x: p.0, y: height - p.1)
    if index == 0 { pulse.move(to: point) } else { pulse.line(to: point) }
}
pulse.lineWidth = 3
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
color(0.39, 0.62, 1).setStroke()
pulse.stroke()
text("MacSense", x: 109, y: 34, w: 320, size: 30, weight: .semibold, tint: .white)
text("Your Mac. At a glance.", x: 110, y: 77, w: 370, size: 12, tint: color(0.69, 0.76, 0.88))
let versionBadge = NSBezierPath(roundedRect: rect(592, 45, 88, 30), xRadius: 15, yRadius: 15)
color(1, 1, 1, 0.09).setFill()
versionBadge.fill()
text("v" + version, x: 592, y: 51, w: 88, size: 12, weight: .medium, tint: color(0.83, 0.88, 0.98), centered: true)

for x: CGFloat in [104, 464] {
    let card = NSBezierPath(roundedRect: rect(x, 166, 152, 151), xRadius: 26, yRadius: 26)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0.23, 0.38, 0.65, 0.12)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.set()
    color(1, 1, 1, 0.82).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0.68, 0.76, 0.9, 0.32).setStroke()
    card.lineWidth = 1
    card.stroke()
}
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 326, y: height - 238))
arrow.line(to: NSPoint(x: 394, y: height - 238))
arrow.move(to: NSPoint(x: 381, y: height - 225))
arrow.line(to: NSPoint(x: 394, y: height - 238))
arrow.line(to: NSPoint(x: 381, y: height - 251))
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
color(0.29, 0.49, 0.85).setStroke()
arrow.stroke()
text("Drag MacSense into Applications", x: 40, y: 348, w: 640, size: 18,
     weight: .semibold, tint: color(0.16, 0.21, 0.31), centered: true)
text("Перетащите MacSense в папку «Программы»", x: 40, y: 378, w: 640, size: 12,
     tint: color(0.40, 0.47, 0.58), centered: true)
color(0.64, 0.71, 0.83, 0.35).setFill()
rect(40, 417, 640, 1).fill()
text("Made by behruzinho", x: 40, y: 432, w: 280, size: 10, tint: color(0.46, 0.53, 0.64))
text("macOS 14+   ·   " + platform, x: 440, y: 432, w: 240, size: 10,
     tint: color(0.46, 0.53, 0.64), centered: true)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .tiff, properties: [:])!.write(to: output)
