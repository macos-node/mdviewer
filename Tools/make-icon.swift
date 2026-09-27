import AppKit

// 1024pt canvas; macOS icon body is 824pt with ~185pt corner radius.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Soft drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
NSColor.white.setFill(); shape.fill()
ctx.restoreGState()

// Background gradient
NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1),
           ending: NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.62, alpha: 1))!
    .draw(in: shape, angle: -90)

// "Page" card
let page = NSRect(x: 232, y: 250, width: 560, height: 524)
let pagePath = NSBezierPath(roundedRect: page, xRadius: 56, yRadius: 56)
NSColor.white.setFill(); pagePath.fill()

// Markdown mark: M + down arrow
let ink = NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.62, alpha: 1)
ink.setStroke(); ink.setFill()
let m = NSBezierPath()
m.lineWidth = 58; m.lineCapStyle = .round; m.lineJoinStyle = .round
m.move(to: NSPoint(x: 322, y: 388))
m.line(to: NSPoint(x: 322, y: 636))
m.line(to: NSPoint(x: 422, y: 530))
m.line(to: NSPoint(x: 522, y: 636))
m.line(to: NSPoint(x: 522, y: 388))
m.stroke()

let shaft = NSBezierPath()
shaft.lineWidth = 58; shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 662, y: 636)); shaft.line(to: NSPoint(x: 662, y: 470))
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 580, y: 480))
head.line(to: NSPoint(x: 744, y: 480))
head.line(to: NSPoint(x: 662, y: 372))
head.close()
head.lineJoinStyle = .round; head.lineWidth = 20
head.fill(); head.stroke()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
// Force exact 1024px output regardless of screen scale.
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
rep.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
