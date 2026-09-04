import AppKit
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = CommandLine.arguments[1]
let iconset = outDir + "/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size*0.02, dy: size*0.02), xRadius: size*0.22, yRadius: size*0.22)
    let grad = NSGradient(colors: [NSColor(calibratedRed: 0.97, green: 0.60, blue: 0.16, alpha: 1),
                                   NSColor(calibratedRed: 0.80, green: 0.18, blue: 0.82, alpha: 1)])!
    grad.draw(in: path, angle: -60)
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.55, weight: .heavy)
    if let sym = NSImage(systemSymbolName: "trophy.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size); tinted.lockFocus()
        NSColor.white.set(); sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSRect(origin: .zero, size: sym.size).fill(using: .sourceAtop); tinted.unlockFocus()
        let s = sym.size
        NSColor.black.withAlphaComponent(0.25).set()
        tinted.draw(in: NSRect(x: (size - s.width)/2, y: (size - s.height)/2 - size*0.02, width: s.width, height: s.height),
                    from: .zero, operation: .sourceOver, fraction: 0.35)
        tinted.draw(in: NSRect(x: (size - s.width)/2, y: (size - s.height)/2 + size*0.01, width: s.width, height: s.height),
                    from: .zero, operation: .sourceOver, fraction: 1)
    }
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}
for px in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(px)x\(px).png"))
    if px <= 512 { try! render(px*2).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(px)x\(px)@2x.png")) }
}
print("iconset at \(iconset)")
