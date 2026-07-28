import AppKit

// Renders the menu-bar pixel engineer (same 16x16 map as
// AppDelegate.createEngineerStatusIcon) onto a 1024x1024 dark tile, crisp
// nearest-neighbour pixels. Output: Resources/icon-1024.png — the master the
// iconset is derived from. Run from the repo root:
//   swift scripts/make-icon.swift

let canvas: CGFloat = 1024
let cells: CGFloat = 16
let cell: CGFloat = 40
let heroPx = cells * cell            // 640
let margin = (canvas - heroPx) / 2   // 192

struct C {
    static let bg = NSColor(red: 0.043, green: 0.063, blue: 0.125, alpha: 1)       // #0B1020
    static let skin = NSColor(red: 0.95, green: 0.74, blue: 0.48, alpha: 1)
    static let hair = NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    static let shirt = NSColor(red: 0.0, green: 0.72, blue: 0.78, alpha: 1)
    static let frame = NSColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1)
    static let lens = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)
}

// Same map as the status-bar icon, y measured from the bottom. Two tweaks
// versus the 18px original so it still reads at 1024px: the lenses get a
// one-cell gap (they are contiguous in the status icon and merge into a blob
// when enlarged), and the whole map shifts up one cell so the character —
// which spans y2...12 — sits optically centred.
let rects: [(x: Int, y: Int, w: Int, h: Int, color: NSColor)] = [
    (5, 6, 6, 5, C.skin),     // head
    (4, 10, 8, 2, C.hair),    // hair top
    (4, 8, 1, 3, C.hair),     // hair left
    (11, 8, 1, 3, C.hair),    // hair right
    (5, 2, 6, 4, C.shirt),    // body
    (5, 7, 6, 1, C.frame),    // glasses bar
    (5, 6, 1, 1, C.frame),    // glasses left arm
    (10, 6, 1, 1, C.frame),   // glasses right arm
    (6, 6, 2, 1, C.lens),     // left lens
    (9, 6, 2, 1, C.lens),     // right lens, one-cell gap at x8
]

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()
C.bg.setFill()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()
for r in rects {
    r.color.setFill()
    NSRect(
        x: margin + CGFloat(r.x) * cell,
        y: margin + CGFloat(r.y + 1) * cell,
        width: CGFloat(r.w) * cell,
        height: CGFloat(r.h) * cell
    ).fill()
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to render PNG")
}

let url = URL(fileURLWithPath: "Resources/icon-1024.png")
try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
)
try png.write(to: url)
print("wrote \(url.path)")
