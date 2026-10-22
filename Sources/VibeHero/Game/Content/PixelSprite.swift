import AppKit

/// One filled cell block on a sprite's 16x16 unit grid.
///
/// Coordinates are in *grid units*, not points, so a sprite is resolution
/// independent: `PixelSpriteRenderer` multiplies by the unit size the view
/// derived from its bounds. Origin is top-left, matching the flipped coordinate
/// space `PixelActorView` draws in.
struct PixelCell {
    enum Shape {
        case rect
        case oval
    }

    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let color: NSColor
    let shape: Shape

    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor, shape: Shape = .rect) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.color = color
        self.shape = shape
    }
}

/// A sprite is just its cells, so adding one is adding data rather than code.
typealias PixelSprite = [PixelCell]

enum PixelSpriteRenderer {
    /// Fills `sprite` into the current graphics context.
    ///
    /// Rects are snapped (`round` the origin, `ceil` the size) so adjacent cells
    /// always meet without hairline seams at fractional unit sizes. Ovals are
    /// left unsnapped — they are soft glows, where snapping would show.
    static func draw(_ sprite: PixelSprite, unit: CGFloat, originX: CGFloat, originY: CGFloat) {
        for cell in sprite {
            cell.color.setFill()
            let x = originX + unit * cell.x
            let y = originY + unit * cell.y
            let width = unit * cell.w
            let height = unit * cell.h

            switch cell.shape {
            case .rect:
                NSBezierPath(
                    rect: NSRect(x: round(x), y: round(y), width: ceil(width), height: ceil(height))
                ).fill()
            case .oval:
                NSBezierPath(
                    ovalIn: NSRect(x: x, y: y, width: width, height: height)
                ).fill()
            }
        }
    }
}

/// Sprites that are not tied to one catalog entry.
enum PixelSprites {
    /// Marks a monster as the stage boss. Drawn over whatever sprite the
    /// monster's own spec supplied.
    static var bossCrown: PixelSprite {
        let gold = NSColor(red: 1.0, green: 0.80, blue: 0.24, alpha: 1)
        return [
            PixelCell(5, 1.2, 6, 1.2, gold),
            PixelCell(5, 0.2, 1, 1, gold),
            PixelCell(7.5, 0.2, 1, 1, gold),
            PixelCell(10, 0.2, 1, 1, gold)
        ]
    }

    /// The hero's shared body. Every role draws this and then layers its own
    /// accessory on top, so a new role only supplies a palette and an accessory.
    static func heroBody(palette: HeroPalette) -> PixelSprite {
        [
            PixelCell(6, 2, 4, 4, palette.skin),
            PixelCell(5, 6, 6, 5, palette.shirt),
            PixelCell(4, 8, 2, 3, palette.sleeve),
            PixelCell(10, 8, 2, 3, palette.sleeve),
            PixelCell(6, 11, 2, 3, palette.pants),
            PixelCell(9, 11, 2, 3, palette.pants),
            PixelCell(6, 1, 4, 1, palette.hair),
            PixelCell(5, 3, 1, 2, palette.hair),
            PixelCell(7, 4, 1, 1, .black),
            PixelCell(9, 4, 1, 1, .black)
        ]
    }

    /// Shown in place of the hero while defeated, until the revive timer fires.
    static var soulHero: PixelSprite {
        let body = NSColor(red: 0.78, green: 0.95, blue: 1.0, alpha: 0.72)
        let glow = NSColor(red: 0.42, green: 0.86, blue: 1.0, alpha: 0.42)
        let eye = NSColor(red: 0.05, green: 0.16, blue: 0.24, alpha: 0.88)

        return [
            PixelCell(4, 1, 8, 12, glow, shape: .oval),
            PixelCell(5, 3, 6, 7, body),
            PixelCell(4, 6, 8, 5, body),
            PixelCell(5, 11, 2, 2, body),
            PixelCell(8, 11, 2, 3, body.withAlphaComponent(0.58)),
            PixelCell(11, 11, 1, 2, body.withAlphaComponent(0.48)),
            PixelCell(6, 6, 1, 1, eye),
            PixelCell(9, 6, 1, 1, eye),
            PixelCell(7, 9, 3, 1, eye.withAlphaComponent(0.64))
        ]
    }
}
