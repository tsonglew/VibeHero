import AppKit

/// The five hero body colors. Everything else about a role's look is its
/// accessory sprite.
struct HeroPalette {
    let skin: NSColor
    let hair: NSColor
    let shirt: NSColor
    let sleeve: NSColor
    let pants: NSColor
}

/// Everything that distinguishes one hero role from another.
///
/// This used to be six parallel `switch` statements spread over two files
/// (labels/multipliers on `HeroRole`, palette and accessory art in the view
/// layer). Adding a role now means one `RoleSpec` here plus its `L10nKey`s.
struct RoleSpec {
    let labelKey: L10nKey
    let detailKey: L10nKey
    let perkKey: L10nKey
    /// Scales damage from token-driven attacks.
    let damageMultiplier: CGFloat
    /// Scales damage from idle attacks (when no tokens are flowing).
    let idleDamageMultiplier: CGFloat
    let palette: HeroPalette
    /// Drawn over `PixelSprites.heroBody`, in 16x16 grid units.
    let accessory: PixelSprite

    init(
        labelKey: L10nKey,
        detailKey: L10nKey,
        perkKey: L10nKey,
        damageMultiplier: CGFloat = 1.0,
        idleDamageMultiplier: CGFloat = 1.0,
        palette: HeroPalette,
        accessory: PixelSprite
    ) {
        self.labelKey = labelKey
        self.detailKey = detailKey
        self.perkKey = perkKey
        self.damageMultiplier = damageMultiplier
        self.idleDamageMultiplier = idleDamageMultiplier
        self.palette = palette
        self.accessory = accessory
    }
}

enum HeroRole: String, CaseIterable {
    case pm
    case designer
    case artist
    case engineer
    case qa
    case other

    var spec: RoleSpec { RoleCatalog.spec(for: self) }

    var label: String { L10n.text(spec.labelKey) }

    var detail: String { L10n.text(spec.detailKey) }

    var perk: String { L10n.text(spec.perkKey) }

    var damageMultiplier: CGFloat { spec.damageMultiplier }

    var idleDamageMultiplier: CGFloat { spec.idleDamageMultiplier }

    var palette: HeroPalette { spec.palette }

    static func load() -> HeroRole {
        guard let rawValue = Defaults.string(forKey: DefaultsKey.selectedRole),
              let role = HeroRole(rawValue: rawValue) else {
            return .other
        }
        return role
    }

    func save() {
        Defaults.set(rawValue, forKey: DefaultsKey.selectedRole)
        NotificationCenter.default.post(name: .vibeHeroRoleChanged, object: self)
    }
}

enum RoleCatalog {
    static let all: [HeroRole: RoleSpec] = [
        .pm: RoleSpec(
            labelKey: .rolePMLabel,
            detailKey: .rolePMDetail,
            perkKey: .rolePMPerk,
            damageMultiplier: 1.04,
            idleDamageMultiplier: 0.92,
            palette: HeroPalette(
                skin: NSColor(red: 0.98, green: 0.75, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.18, green: 0.12, blue: 0.10, alpha: 1),
                shirt: NSColor(red: 0.14, green: 0.42, blue: 0.95, alpha: 1),
                sleeve: NSColor(red: 0.08, green: 0.28, blue: 0.78, alpha: 1),
                pants: NSColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
            ),
            // Highlighter and a roadmap board.
            accessory: [
                PixelCell(7, 6, 2, 5, NSColor(red: 0.98, green: 0.93, blue: 0.45, alpha: 1)),
                PixelCell(11, 4, 4, 7, NSColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 1)),
                PixelCell(12, 5, 2, 1, NSColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1)),
                PixelCell(12, 7, 2, 1, NSColor(red: 0.28, green: 0.92, blue: 0.66, alpha: 1)),
                PixelCell(12, 9, 2, 1, NSColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1))
            ]
        ),
        .designer: RoleSpec(
            labelKey: .roleDesignerLabel,
            detailKey: .roleDesignerDetail,
            perkKey: .roleDesignerPerk,
            palette: HeroPalette(
                skin: NSColor(red: 0.96, green: 0.74, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.58, green: 0.38, blue: 0.86, alpha: 1),
                shirt: NSColor(red: 0.62, green: 0.37, blue: 1.0, alpha: 1),
                sleeve: NSColor(red: 0.82, green: 0.62, blue: 1.0, alpha: 1),
                pants: NSColor(red: 0.18, green: 0.15, blue: 0.34, alpha: 1)
            ),
            // Wireframe panel and a stylus.
            accessory: [
                PixelCell(11, 4, 4, 6, NSColor(red: 0.80, green: 0.73, blue: 1.0, alpha: 1)),
                PixelCell(12, 5, 1, 1, NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1)),
                PixelCell(14, 5, 1, 1, NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1)),
                PixelCell(13, 7, 1, 1, NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1)),
                PixelCell(12, 8, 3, 1, NSColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1)),
                PixelCell(3, 4, 1, 5, NSColor(red: 0.98, green: 0.96, blue: 0.72, alpha: 1))
            ]
        ),
        .artist: RoleSpec(
            labelKey: .roleArtistLabel,
            detailKey: .roleArtistDetail,
            perkKey: .roleArtistPerk,
            idleDamageMultiplier: 0.82,
            palette: HeroPalette(
                skin: NSColor(red: 0.98, green: 0.76, blue: 0.52, alpha: 1),
                hair: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1),
                shirt: NSColor(red: 1.0, green: 0.34, blue: 0.46, alpha: 1),
                sleeve: NSColor(red: 0.98, green: 0.73, blue: 0.23, alpha: 1),
                pants: NSColor(red: 0.10, green: 0.28, blue: 0.48, alpha: 1)
            ),
            // Canvas with paint dabs, plus a brush.
            accessory: [
                PixelCell(11, 3, 4, 6, NSColor(red: 0.96, green: 0.96, blue: 0.86, alpha: 1)),
                PixelCell(12, 4, 1, 1, NSColor(red: 1.0, green: 0.28, blue: 0.36, alpha: 1)),
                PixelCell(14, 5, 1, 1, NSColor(red: 0.22, green: 0.66, blue: 1.0, alpha: 1)),
                PixelCell(13, 7, 1, 1, NSColor(red: 0.98, green: 0.74, blue: 0.22, alpha: 1)),
                PixelCell(3, 4, 1, 6, NSColor(red: 0.34, green: 0.21, blue: 0.13, alpha: 1)),
                PixelCell(2, 3, 1, 2, NSColor(red: 0.23, green: 0.93, blue: 0.78, alpha: 1))
            ]
        ),
        .engineer: RoleSpec(
            labelKey: .roleEngineerLabel,
            detailKey: .roleEngineerDetail,
            perkKey: .roleEngineerPerk,
            damageMultiplier: 1.15,
            palette: HeroPalette(
                skin: NSColor(red: 0.95, green: 0.74, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
                shirt: NSColor(red: 0.0, green: 0.72, blue: 0.78, alpha: 1),
                sleeve: NSColor(red: 0.0, green: 0.48, blue: 0.56, alpha: 1),
                pants: NSColor(red: 0.14, green: 0.18, blue: 0.25, alpha: 1)
            ),
            // Visor over the eyes and a terminal on a stand.
            accessory: [
                PixelCell(6, 4, 4, 1, NSColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1)),
                PixelCell(7, 4, 1, 1, NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)),
                PixelCell(9, 4, 1, 1, NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1)),
                PixelCell(11, 5, 4, 4, NSColor(red: 0.08, green: 0.12, blue: 0.17, alpha: 1)),
                PixelCell(12, 6, 2, 2, NSColor(red: 0.0, green: 0.86, blue: 0.88, alpha: 1)),
                PixelCell(10, 9, 5, 1, NSColor(red: 0.34, green: 0.39, blue: 0.47, alpha: 1))
            ]
        ),
        .qa: RoleSpec(
            labelKey: .roleQALabel,
            detailKey: .roleQADetail,
            perkKey: .roleQAPerk,
            idleDamageMultiplier: 0.75,
            palette: HeroPalette(
                skin: NSColor(red: 0.98, green: 0.77, blue: 0.48, alpha: 1),
                hair: NSColor(red: 0.54, green: 0.35, blue: 0.12, alpha: 1),
                shirt: NSColor(red: 0.22, green: 0.78, blue: 0.42, alpha: 1),
                sleeve: NSColor(red: 0.10, green: 0.52, blue: 0.32, alpha: 1),
                pants: NSColor(red: 0.12, green: 0.24, blue: 0.22, alpha: 1)
            ),
            // Magnifier and a checklist.
            accessory: [
                PixelCell(11, 4, 3, 3, NSColor(red: 0.84, green: 0.96, blue: 1.0, alpha: 1)),
                PixelCell(12, 5, 1, 1, NSColor(red: 0.04, green: 0.08, blue: 0.12, alpha: 1)),
                PixelCell(14, 7, 1, 3, NSColor(red: 0.84, green: 0.96, blue: 1.0, alpha: 1)),
                PixelCell(3, 4, 2, 5, NSColor(red: 0.13, green: 0.24, blue: 0.23, alpha: 1)),
                PixelCell(4, 6, 1, 1, NSColor(red: 0.30, green: 1.0, blue: 0.57, alpha: 1)),
                PixelCell(4, 7, 1, 1, NSColor(red: 0.30, green: 1.0, blue: 0.57, alpha: 1))
            ]
        ),
        .other: RoleSpec(
            labelKey: .roleOtherLabel,
            detailKey: .roleOtherDetail,
            perkKey: .roleOtherPerk,
            palette: HeroPalette(
                skin: NSColor(red: 0.98, green: 0.76, blue: 0.35, alpha: 1),
                hair: NSColor(red: 0.30, green: 0.17, blue: 0.08, alpha: 1),
                shirt: NSColor(red: 0.04, green: 0.82, blue: 0.72, alpha: 1),
                sleeve: NSColor(red: 0.0, green: 0.55, blue: 0.85, alpha: 1),
                pants: NSColor(red: 0.19, green: 0.22, blue: 0.34, alpha: 1)
            ),
            // A plain wand.
            accessory: [
                PixelCell(11, 5, 4, 1, NSColor(red: 0.97, green: 0.94, blue: 0.78, alpha: 1)),
                PixelCell(14, 3, 1, 5, NSColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1))
            ]
        )
    ]

    /// The fallback only fires if `all` is missing a case, which
    /// `RoleCatalogTests` asserts cannot happen — better than trapping in a
    /// menu-bar app that would otherwise be unrecoverable.
    static func spec(for role: HeroRole) -> RoleSpec {
        all[role] ?? all[.other] ?? RoleSpec(
            labelKey: .roleOtherLabel,
            detailKey: .roleOtherDetail,
            perkKey: .roleOtherPerk,
            palette: HeroPalette(skin: .orange, hair: .brown, shirt: .cyan, sleeve: .blue, pants: .darkGray),
            accessory: []
        )
    }
}

extension Notification.Name {
    static let vibeHeroRoleChanged = Notification.Name(DefaultsKey.prefix + "roleChanged")
}
