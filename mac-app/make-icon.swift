// Draws the app icon (1024×1024 PNG) from the Claude logo (mac-app/claude-logo.png) plus a dashboard gauge.
// Usage: swift mac-app/make-icon.swift <variant a|b|c> out.png
import AppKit

let args = CommandLine.arguments
let variant = args.count > 1 ? args[1] : "a"
let out = args.count > 2 ? args[2] : "icon.png"
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let logo = NSImage(contentsOf: here.appendingPathComponent("claude-logo.png"))!
    .cgImage(forProposedRect: nil, context: nil, hints: nil)!

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let orangeTop: UInt32 = 0xE07D58, orangeBot: UInt32 = 0xD8643F
let green: UInt32 = 0x5FD38D, amber: UInt32 = 0xFFC23D, red: UInt32 = 0xFF6B5B

// Burst mask: the logo's white pixels, cropped to the burst.
let burstMask: CGImage = {
    let w = logo.width, h = logo.height
    let src = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    src.draw(logo, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = src.data!.assumingMemoryBound(to: UInt8.self)
    var gray = [UInt8](repeating: 0, count: w * h)
    var minX = w, minY = h, maxX = 0, maxY = 0
    for y in 0..<h { for x in 0..<w {
        let i = (y * w + x) * 4
        let m = min(px[i], px[i + 1], px[i + 2]), a = px[i + 3]
        let inside = x > w * 18 / 100 && x < w * 82 / 100 && y > h * 18 / 100 && y < h * 82 / 100  // skip the tile's light rim
        let v = inside && a > 200 && m > 180 ? UInt8(min(255, (Int(m) - 180) * 255 / 60)) : 0
        gray[y * w + x] = v
        if v > 128 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
    }}
    let g = CGContext(data: &gray, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
    return g.makeImage()!.cropping(to: CGRect(x: minX - 4, y: minY - 4, width: maxX - minX + 8, height: maxY - minY + 8))!
}()

func burst(center c: CGPoint, size d: CGFloat, color: CGColor, shadow: Bool = true) {
    let r = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
    ctx.saveGState()
    if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x5A1E0A, 0.35)) }
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.clip(to: r, mask: burstMask); ctx.setFillColor(color); ctx.fill(r)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
func drawTile(_ top: UInt32, _ bottom: UInt32) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(bottom)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(tilePath); ctx.clip()
    ctx.drawLinearGradient(CGGradient(colorsSpace: cs, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!,
                           start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    ctx.restoreGState()
}

func pt(_ c: CGPoint, _ r: CGFloat, _ deg: CGFloat) -> CGPoint {
    CGPoint(x: c.x + r * cos(deg * .pi / 180), y: c.y + r * sin(deg * .pi / 180))
}

// Half-circle gauge (180° → 0°) in coloured bands; angles in degrees, counter-clockwise from the right.
func gauge(center c: CGPoint, radius r: CGFloat, width w: CGFloat, bands: [(CGFloat, CGFloat, CGColor)]) {
    ctx.saveGState(); ctx.setLineWidth(w); ctx.setLineCap(.butt)
    for (from, to, col) in bands {
        ctx.setStrokeColor(col)
        ctx.addArc(center: c, radius: r, startAngle: from * .pi / 180, endAngle: to * .pi / 180, clockwise: true)
        ctx.strokePath()
    }
    ctx.restoreGState()
}

func ticks(center c: CGPoint, from r0: CGFloat, to r1: CGFloat, count: Int, color: CGColor, width: CGFloat) {
    ctx.saveGState(); ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.setLineCap(.round)
    for i in 0..<count {
        let a = 180 - 180 * CGFloat(i) / CGFloat(count - 1)
        ctx.move(to: pt(c, r0, a)); ctx.addLine(to: pt(c, r1, a)); ctx.strokePath()
    }
    ctx.restoreGState()
}

func needle(pivot c: CGPoint, angle deg: CGFloat, length: CGFloat, base: CGFloat, color: CGColor) {
    let a = deg * .pi / 180, nx = -sin(a), ny = cos(a)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x + nx * base, y: c.y + ny * base))
    p.addLine(to: CGPoint(x: c.x + cos(a) * length, y: c.y + sin(a) * length))
    p.addLine(to: CGPoint(x: c.x - nx * base, y: c.y - ny * base))
    p.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: rgb(0, 0.3))
    ctx.addPath(p); ctx.setFillColor(color); ctx.fillPath()
    ctx.restoreGState()
}

func dots(y: CGFloat, x0: CGFloat, r: CGFloat, gap: CGFloat, colors: [CGColor]) {
    for (i, col) in colors.enumerated() {
        let x = x0 + CGFloat(i) * gap
        ctx.setFillColor(rgb(0, 0.18)); ctx.fillEllipse(in: CGRect(x: x - r - 5, y: y - r - 5, width: 2 * r + 10, height: 2 * r + 10))
        ctx.setFillColor(col); ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
}

switch variant {
case "a":  // Speedometer: big half dial, needle springs out of the Claude burst at the hub.
    drawTile(orangeTop, orangeBot)
    let c = CGPoint(x: 512, y: 420)
    gauge(center: c, radius: 300, width: 70, bands: [(180, 122, rgb(green)), (119, 61, rgb(amber)), (58, 0, rgb(0xFFFFFF, 0.35))])
    ticks(center: c, from: 220, to: 245, count: 9, color: rgb(0xFFFFFF, 0.85), width: 12)
    needle(pivot: c, angle: 72, length: 300, base: 26, color: rgb(0xFFFFFF))
    burst(center: c, size: 300, color: rgb(0xFFFFFF))
    dots(y: 220, x0: 512 - 1.5 * 70, r: 24, gap: 70, colors: [rgb(amber), rgb(green), rgb(green), rgb(0xFFFFFF, 0.5)])
case "b":  // Dark dashboard tile with a bright gauge; the original Claude icon as a big corner badge.
    drawTile(0x34302C, 0x1E1B19)
    let c = CGPoint(x: 512, y: 565)
    gauge(center: c, radius: 270, width: 62, bands: [(180, 122, rgb(green)), (119, 61, rgb(amber)), (58, 0, rgb(red))])
    ticks(center: c, from: 188, to: 214, count: 9, color: rgb(0xFFFFFF, 0.6), width: 12)
    needle(pivot: c, angle: 128, length: 250, base: 24, color: rgb(0xF4EFE8))
    ctx.setFillColor(rgb(0xF4EFE8)); ctx.fillEllipse(in: CGRect(x: c.x - 40, y: c.y - 40, width: 80, height: 80))
    dots(y: 300, x0: 220, r: 22, gap: 64, colors: [rgb(amber), rgb(green), rgb(green)])
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0, 0.55))
    // The logo PNG has a ~10% margin; keep its visible tile inside ours, or macOS frames the icon in grey.
    ctx.draw(logo, in: CGRect(x: 488, y: 96, width: 440, height: 440))
    ctx.restoreGState()
case "c":  // Orange tile, bold white half dial up top, oversized Claude burst bleeding off the bottom-left corner.
    drawTile(orangeTop, orangeBot)
    ctx.saveGState(); ctx.addPath(tilePath); ctx.clip()
    burst(center: CGPoint(x: 250, y: 250), size: 560, color: rgb(0xFFFFFF))
    ctx.restoreGState()
    let c = CGPoint(x: 600, y: 560)
    gauge(center: c, radius: 250, width: 64, bands: [(180, 122, rgb(green)), (119, 61, rgb(amber)), (58, 0, rgb(0xFFFFFF, 0.45))])
    needle(pivot: c, angle: 50, length: 250, base: 24, color: rgb(0x3A1A0E))
    ctx.setFillColor(rgb(0x3A1A0E)); ctx.fillEllipse(in: CGRect(x: c.x - 36, y: c.y - 36, width: 72, height: 72))
    dots(y: 420, x0: 600 - 64, r: 22, gap: 64, colors: [rgb(amber), rgb(green), rgb(green)])
default: fatalError("variant must be a, b or c")
}

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
