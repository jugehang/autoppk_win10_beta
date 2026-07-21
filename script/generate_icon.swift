import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AutoPMX.iconset")
let icns = root.appendingPathComponent("Resources/AutoPMX.icns")
let duduButton = root.appendingPathComponent("Resources/DuDuPMxButton.png")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func withShadow(color: NSColor, blur: CGFloat, offset: NSSize, draw: () -> Void) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    draw()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawRotatedCapsule(rect: NSRect, angle: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    NSGraphicsContext.current?.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: angle)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)
    transform.concat()
    let path = rounded(rect, min(rect.width, rect.height) / 2)
    color.withAlphaComponent(alpha).setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func drawDuDu(in rect: NSRect, shadow: Bool) {
    let x = rect.minX
    let y = rect.minY
    let w = rect.width
    let h = rect.height
    let s = min(w, h)

    func r(_ nx: CGFloat, _ ny: CGFloat, _ nw: CGFloat, _ nh: CGFloat) -> NSRect {
        NSRect(x: x + nx * w, y: y + ny * h, width: nw * w, height: nh * h)
    }

    if shadow {
        let shadowPath = NSBezierPath(ovalIn: r(0.22, 0.015, 0.56, 0.09))
        NSColor.black.withAlphaComponent(0.20).setFill()
        shadowPath.fill()
    }

    withShadow(color: .black.withAlphaComponent(0.16), blur: s * 0.035, offset: NSSize(width: 0, height: -s * 0.010)) {
        drawRotatedCapsule(rect: r(0.16, 0.26, 0.17, 0.34), angle: 16, color: .white)
        drawRotatedCapsule(rect: r(0.67, 0.26, 0.17, 0.34), angle: -16, color: .white)
    }

    let belly = rounded(r(0.27, 0.08, 0.46, 0.38), s * 0.16)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.90, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.97, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.20, blue: 0.74, alpha: 1)
    ])!.draw(in: belly, angle: 90)
    stroke(belly, color: .white.withAlphaComponent(0.55), width: max(1, s * 0.014))

    let bellyGlow = NSBezierPath(ovalIn: r(0.33, 0.27, 0.24, 0.10))
    NSColor.white.withAlphaComponent(0.28).setFill()
    bellyGlow.fill()

    NSColor.white.setFill()
    withShadow(color: .black.withAlphaComponent(0.14), blur: s * 0.025, offset: NSSize(width: 0, height: -s * 0.006)) {
        rounded(r(0.13, 0.43, 0.15, 0.24), s * 0.065).fill()
        rounded(r(0.72, 0.43, 0.15, 0.24), s * 0.065).fill()
    }

    NSColor.white.setFill()
    rounded(r(0.13, 0.43, 0.15, 0.24), s * 0.065).fill()
    rounded(r(0.72, 0.43, 0.15, 0.24), s * 0.065).fill()

    let head = rounded(r(0.17, 0.39, 0.66, 0.42), s * 0.17)
    withShadow(color: .black.withAlphaComponent(0.17), blur: s * 0.040, offset: NSSize(width: 0, height: -s * 0.012)) {
        NSGradient(colors: [
            .white,
            NSColor(calibratedRed: 0.88, green: 0.94, blue: 1.00, alpha: 1)
        ])!.draw(in: head, angle: 112)
    }

    let headHighlight = rounded(r(0.29, 0.68, 0.31, 0.07), s * 0.035)
    NSColor.white.withAlphaComponent(0.56).setFill()
    headHighlight.fill()

    let antenna = NSBezierPath()
    antenna.move(to: NSPoint(x: x + 0.51 * w, y: y + 0.79 * h))
    antenna.curve(
        to: NSPoint(x: x + 0.58 * w, y: y + 0.94 * h),
        controlPoint1: NSPoint(x: x + 0.58 * w, y: y + 0.84 * h),
        controlPoint2: NSPoint(x: x + 0.53 * w, y: y + 0.90 * h)
    )
    stroke(antenna, color: NSColor(calibratedRed: 1.00, green: 0.47, blue: 0.18, alpha: 1), width: max(2, s * 0.030))
    stroke(antenna, color: .white.withAlphaComponent(0.72), width: max(1, s * 0.010))

    let star = NSBezierPath(ovalIn: r(0.545, 0.915, 0.075, 0.075))
    NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.16, alpha: 1).setFill()
    star.fill()

    let visor = rounded(r(0.235, 0.505, 0.53, 0.245), s * 0.12)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.18, alpha: 1)
    ])!.draw(in: visor, angle: 90)
    stroke(visor, color: .white.withAlphaComponent(0.35), width: max(1, s * 0.010))

    let leftEye = NSBezierPath()
    leftEye.move(to: NSPoint(x: x + 0.34 * w, y: y + 0.61 * h))
    leftEye.curve(
        to: NSPoint(x: x + 0.45 * w, y: y + 0.61 * h),
        controlPoint1: NSPoint(x: x + 0.37 * w, y: y + 0.69 * h),
        controlPoint2: NSPoint(x: x + 0.42 * w, y: y + 0.69 * h)
    )
    let rightEye = NSBezierPath()
    rightEye.move(to: NSPoint(x: x + 0.55 * w, y: y + 0.61 * h))
    rightEye.curve(
        to: NSPoint(x: x + 0.66 * w, y: y + 0.61 * h),
        controlPoint1: NSPoint(x: x + 0.58 * w, y: y + 0.69 * h),
        controlPoint2: NSPoint(x: x + 0.63 * w, y: y + 0.69 * h)
    )
    stroke(leftEye, color: NSColor(calibratedRed: 0.70, green: 0.96, blue: 1.00, alpha: 1), width: max(2, s * 0.038))
    stroke(rightEye, color: NSColor(calibratedRed: 0.70, green: 0.96, blue: 1.00, alpha: 1), width: max(2, s * 0.038))

    let shield = rounded(r(0.375, 0.17, 0.25, 0.18), s * 0.045)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.03, green: 0.10, blue: 0.36, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.88, alpha: 1)
    ])!.draw(in: shield, angle: 90)
    stroke(shield, color: .white.withAlphaComponent(0.76), width: max(1, s * 0.010))

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let aiAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: s * 0.105, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    "AI".draw(in: r(0.39, 0.205, 0.22, 0.10), withAttributes: aiAttrs)

    let swoosh = NSBezierPath()
    swoosh.move(to: NSPoint(x: x + 0.415 * w, y: y + 0.205 * h))
    swoosh.curve(
        to: NSPoint(x: x + 0.585 * w, y: y + 0.205 * h),
        controlPoint1: NSPoint(x: x + 0.47 * w, y: y + 0.165 * h),
        controlPoint2: NSPoint(x: x + 0.54 * w, y: y + 0.165 * h)
    )
    stroke(swoosh, color: NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.12, alpha: 1), width: max(1, s * 0.016))
}

func pngData(from image: NSImage) throws -> Data {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "AutoPMXIcon", code: 1)
    }
    return png
}

func drawAppIcon(pixelSize: Int) throws -> Data {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let iconRect = rect.insetBy(dx: size * 0.055, dy: size * 0.055)
    let background = NSBezierPath(ovalIn: iconRect)
    NSGraphicsContext.current?.saveGraphicsState()
    background.addClip()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.22, green: 0.96, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.39, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.72, green: 0.28, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.98, blue: 0.76, alpha: 1)
    ])!.draw(in: background, angle: 132)

    let glassTop = NSBezierPath(ovalIn: NSRect(x: size * 0.11, y: size * 0.56, width: size * 0.48, height: size * 0.28))
    NSGradient(colors: [
        .white.withAlphaComponent(0.70),
        .white.withAlphaComponent(0.10)
    ])!.draw(in: glassTop, angle: 112)

    let glow = NSBezierPath(ovalIn: NSRect(x: size * 0.45, y: size * 0.04, width: size * 0.50, height: size * 0.34))
    NSColor(calibratedRed: 0.62, green: 1.00, blue: 0.94, alpha: 0.28).setFill()
    glow.fill()

    let blush = NSBezierPath(ovalIn: NSRect(x: size * 0.02, y: size * 0.16, width: size * 0.42, height: size * 0.42))
    NSColor(calibratedRed: 0.92, green: 0.42, blue: 1.00, alpha: 0.18).setFill()
    blush.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    drawDuDu(in: NSRect(x: size * 0.13, y: size * 0.045, width: size * 0.74, height: size * 0.86), shadow: true)

    let border = NSBezierPath(ovalIn: iconRect.insetBy(dx: size * 0.006, dy: size * 0.006))
    stroke(border, color: .white.withAlphaComponent(0.42), width: max(1, size * 0.010))

    image.unlockFocus()
    return try pngData(from: image)
}

func drawButton(pixelSize: Int) throws -> Data {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    drawDuDu(in: rect.insetBy(dx: size * 0.08, dy: size * 0.06), shadow: true)
    image.unlockFocus()
    return try pngData(from: image)
}

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in specs {
    try drawAppIcon(pixelSize: size).write(to: iconset.appendingPathComponent(name))
}
try drawButton(pixelSize: 512).write(to: duduButton)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "AutoPMXIcon", code: Int(process.terminationStatus))
}
