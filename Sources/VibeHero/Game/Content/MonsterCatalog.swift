import AppKit

/// Everything that defines a monster.
///
/// This replaced seven parallel `switch` statements on `MonsterKind` plus a
/// dispatch `switch` and four draw methods in `PixelActorView`. Adding a monster
/// is one `MonsterSpec` here and its `L10nKey`s — no view code to touch.
struct MonsterSpec {
    let displayNameKey: L10nKey
    let shortNameKey: L10nKey
    /// Tint for the monster's HP bar.
    let hpColor: NSColor
    /// Base HP before stage and boss scaling (see `StageProgress.maxHP`).
    let maxHP: Int
    let xpReward: Int
    /// Colors for the death-burst shards.
    let shardColors: [NSColor]
    /// The sprite, in 16x16 grid units.
    let sprite: PixelSprite
}

enum MonsterKind: CaseIterable {
    case promptWraith
    case cacheGolem
    case tokenSlime
    case nullSentinel

    var spec: MonsterSpec { MonsterCatalog.spec(for: self) }

    var displayName: String { L10n.text(spec.displayNameKey) }

    var shortName: String { L10n.text(spec.shortNameKey) }

    var hpColor: NSColor { spec.hpColor }

    var maxHP: Int { spec.maxHP }

    var xpReward: Int { spec.xpReward }

    var shardColors: [NSColor] { spec.shardColors }

    /// Encounter rotation order, so the queue cycles through every monster
    /// rather than repeating one.
    var next: MonsterKind {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .promptWraith
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum MonsterCatalog {
    static let all: [MonsterKind: MonsterSpec] = [
        .promptWraith: MonsterSpec(
            displayNameKey: .monsterPromptWraith,
            shortNameKey: .monsterPromptWraithShort,
            hpColor: NSColor(red: 1.0, green: 0.33, blue: 0.29, alpha: 1.0),
            maxHP: 120,
            xpReward: 45,
            shardColors: [
                NSColor(red: 0.92, green: 0.23, blue: 0.26, alpha: 1),
                NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1),
                NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1)
            ],
            sprite: [
                PixelCell(4, 4, 8, 7, NSColor(red: 0.92, green: 0.23, blue: 0.26, alpha: 1)),
                PixelCell(3, 6, 2, 3, NSColor(red: 0.65, green: 0.12, blue: 0.2, alpha: 1)),
                PixelCell(11, 6, 2, 3, NSColor(red: 0.65, green: 0.12, blue: 0.2, alpha: 1)),
                PixelCell(5, 3, 2, 2, NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1)),
                PixelCell(9, 3, 2, 2, NSColor(red: 1.0, green: 0.69, blue: 0.19, alpha: 1)),
                PixelCell(6, 6, 1, 1, .black),
                PixelCell(10, 6, 1, 1, .black),
                PixelCell(6, 10, 4, 1, NSColor.white.withAlphaComponent(0.75)),
                PixelCell(5, 11, 2, 2, NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1)),
                PixelCell(10, 11, 2, 2, NSColor(red: 0.36, green: 0.08, blue: 0.14, alpha: 1))
            ]
        ),
        .cacheGolem: MonsterSpec(
            displayNameKey: .monsterCacheGolem,
            shortNameKey: .monsterCacheGolemShort,
            hpColor: NSColor(red: 0.34, green: 0.82, blue: 0.78, alpha: 1.0),
            maxHP: 170,
            xpReward: 65,
            shardColors: [
                NSColor(red: 0.28, green: 0.34, blue: 0.40, alpha: 1),
                NSColor(red: 0.0, green: 0.88, blue: 0.78, alpha: 1),
                NSColor(red: 0.70, green: 0.78, blue: 0.82, alpha: 1)
            ],
            sprite: {
                let stone = NSColor(red: 0.30, green: 0.36, blue: 0.42, alpha: 1)
                let dark = NSColor(red: 0.14, green: 0.18, blue: 0.23, alpha: 1)
                let light = NSColor(red: 0.62, green: 0.72, blue: 0.78, alpha: 1)
                let core = NSColor(red: 0.0, green: 0.88, blue: 0.78, alpha: 1)

                return [
                    PixelCell(5, 3, 6, 3, stone),
                    PixelCell(4, 6, 8, 6, stone),
                    PixelCell(3, 7, 2, 4, dark),
                    PixelCell(11, 7, 2, 4, dark),
                    PixelCell(5, 12, 3, 2, dark),
                    PixelCell(9, 12, 3, 2, dark),
                    PixelCell(6, 7, 4, 3, core),
                    PixelCell(6, 4, 1, 1, light),
                    PixelCell(9, 4, 1, 1, light),
                    PixelCell(7, 8, 2, 1, NSColor.white.withAlphaComponent(0.72))
                ]
            }()
        ),
        .tokenSlime: MonsterSpec(
            displayNameKey: .monsterTokenSlime,
            shortNameKey: .monsterTokenSlimeShort,
            hpColor: NSColor(red: 0.58, green: 1.0, blue: 0.35, alpha: 1.0),
            maxHP: 95,
            xpReward: 35,
            shardColors: [
                NSColor(red: 0.38, green: 0.90, blue: 0.32, alpha: 1),
                NSColor(red: 0.92, green: 1.0, blue: 0.35, alpha: 1),
                NSColor(red: 0.12, green: 0.42, blue: 0.22, alpha: 1)
            ],
            sprite: {
                let body = NSColor(red: 0.38, green: 0.90, blue: 0.32, alpha: 1)
                let dark = NSColor(red: 0.12, green: 0.42, blue: 0.22, alpha: 1)
                let glow = NSColor(red: 0.92, green: 1.0, blue: 0.35, alpha: 1)

                return [
                    PixelCell(5, 5, 6, 2, body),
                    PixelCell(4, 7, 8, 5, body),
                    PixelCell(3, 9, 10, 3, body),
                    PixelCell(5, 12, 7, 2, dark),
                    PixelCell(6, 8, 1, 1, .black),
                    PixelCell(10, 8, 1, 1, .black),
                    PixelCell(7, 10, 3, 1, dark),
                    PixelCell(6, 4, 4, 1, glow),
                    PixelCell(7, 3, 2, 1, NSColor(red: 1.0, green: 0.82, blue: 0.26, alpha: 1)),
                    PixelCell(12, 6, 1, 2, glow)
                ]
            }()
        ),
        .nullSentinel: MonsterSpec(
            displayNameKey: .monsterNullSentinel,
            shortNameKey: .monsterNullSentinelShort,
            hpColor: NSColor(red: 0.78, green: 0.52, blue: 1.0, alpha: 1.0),
            maxHP: 145,
            xpReward: 55,
            shardColors: [
                NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1),
                NSColor(red: 0.68, green: 0.44, blue: 1.0, alpha: 1),
                NSColor(red: 0.24, green: 0.30, blue: 0.42, alpha: 1)
            ],
            sprite: {
                let armor = NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1)
                let plate = NSColor(red: 0.24, green: 0.30, blue: 0.42, alpha: 1)
                let glow = NSColor(red: 0.68, green: 0.44, blue: 1.0, alpha: 1)

                return [
                    PixelCell(5, 2, 6, 4, armor),
                    PixelCell(4, 6, 8, 6, plate),
                    PixelCell(3, 7, 1, 5, armor),
                    PixelCell(12, 7, 1, 5, armor),
                    PixelCell(6, 12, 2, 2, armor),
                    PixelCell(9, 12, 2, 2, armor),
                    PixelCell(6, 4, 4, 1, glow),
                    PixelCell(7, 8, 2, 2, glow.withAlphaComponent(0.78)),
                    PixelCell(4, 3, 1, 3, glow),
                    PixelCell(11, 3, 1, 3, glow),
                    PixelCell(5, 10, 6, 1, armor)
                ]
            }()
        )
    ]

    /// The fallback only fires if `all` is missing a case, which
    /// `ContentCatalogTests` asserts cannot happen — better than trapping in a
    /// menu-bar app the user cannot restart from the UI.
    static func spec(for kind: MonsterKind) -> MonsterSpec {
        all[kind] ?? all[.promptWraith] ?? MonsterSpec(
            displayNameKey: .monsterPromptWraith,
            shortNameKey: .monsterPromptWraithShort,
            hpColor: .red,
            maxHP: 120,
            xpReward: 45,
            shardColors: [.red],
            sprite: []
        )
    }
}
