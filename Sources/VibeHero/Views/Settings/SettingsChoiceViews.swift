import AppKit

final class RoleChoiceView: NSView {
    let role: HeroRole
    var onSelected: ((HeroRole) -> Void)?
    private let actorView = PixelActorView(kind: .hero)
    let nameLabel = NSTextField(labelWithString: "")
    let perkLabel = NSTextField(labelWithString: "")
    let clickButton = NSButton(title: "", target: nil, action: nil)
    private var selected = false

    var compactAttributes: String {
        L10n.string(.roleStatsShort,
                    Int(((role.damageMultiplier - 1) * 100).rounded()),
                    Int(((role.idleDamageMultiplier - 1) * 100).rounded()))
    }

    init(role: HeroRole) {
        self.role = role
        super.init(frame: .zero)
        setup()
        refresh(selectedRole: HeroRole.load())
    }
    required init?(coder: NSCoder) { nil }

    func refresh(selectedRole: HeroRole) {
        actorView.heroRole = role
        nameLabel.stringValue = role.label
        perkLabel.stringValue = compactAttributes
        selected = selectedRole == role
        clickButton.state = selected ? .on : .off
        let detail = L10n.string(.roleChoiceAccessibility, role.label, compactAttributes, role.perk)
        clickButton.setAccessibilityLabel(detail)
        clickButton.setAccessibilityValue(selected ? 1 : 0)
        clickButton.toolTip = role.detail + "\n" + role.perk
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = (selected ? NSColor.controlAccentColor : .separatorColor).cgColor
            layer?.borderWidth = selected ? 2 : 1
            layer?.backgroundColor = (selected
                ? NSColor.controlAccentColor.withAlphaComponent(0.13)
                : NSColor.controlBackgroundColor).cgColor
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        // Leave the native focus ring visible around the card.
        layer?.masksToBounds = false
        actorView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        perkLabel.translatesAutoresizingMaskIntoConstraints = false
        clickButton.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        perkLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        perkLabel.textColor = .secondaryLabelColor
        perkLabel.alignment = .center
        perkLabel.lineBreakMode = .byWordWrapping
        perkLabel.maximumNumberOfLines = 2
        for child in [actorView, nameLabel, perkLabel] { child.setAccessibilityElement(false) }
        clickButton.isBordered = false
        clickButton.setButtonType(.toggle)
        clickButton.refusesFirstResponder = false
        clickButton.focusRingType = .exterior
        clickButton.setAccessibilityRole(.radioButton)
        clickButton.target = self
        clickButton.action = #selector(selectRole)
        for child in [actorView, nameLabel, perkLabel, clickButton] { addSubview(child) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 110),
            actorView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            actorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            actorView.widthAnchor.constraint(equalToConstant: 38),
            actorView.heightAnchor.constraint(equalToConstant: 38),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: actorView.bottomAnchor, constant: 4),
            nameLabel.heightAnchor.constraint(equalToConstant: 16),
            perkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            perkLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            perkLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            perkLabel.heightAnchor.constraint(equalToConstant: 28),
            clickButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clickButton.topAnchor.constraint(equalTo: topAnchor),
            clickButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func selectRole() { onSelected?(role) }
}

final class BackdropChoiceView: NSView {
    let backdrop: BattleBackdrop
    var onSelected: ((BattleBackdrop) -> Void)?

    private let previewView = BackdropView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let clickButton = NSButton(title: "", target: nil, action: nil)

    init(backdrop: BattleBackdrop) {
        self.backdrop = backdrop
        super.init(frame: .zero)
        setup()
        previewView.backdrop = backdrop
        nameLabel.stringValue = backdrop.name
        refreshSelection()
    }

    required init?(coder: NSCoder) { nil }

    func refreshSelection() {
        nameLabel.stringValue = backdrop.name
        let isSelected = BattleBackdrop.load() == backdrop
        clickButton.state = isSelected ? .on : .off
        clickButton.setAccessibilityLabel(backdrop.name)
        clickButton.setAccessibilityValue(isSelected ? 1 : 0)
        clickButton.toolTip = backdrop.name
        layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        layer?.borderWidth = isSelected ? 2 : 1
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.13).cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        previewView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        clickButton.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        clickButton.isBordered = false
        clickButton.setButtonType(.toggle)
        clickButton.refusesFirstResponder = false
        clickButton.focusRingType = .exterior
        clickButton.target = self
        clickButton.action = #selector(selectBackdrop)

        addSubview(previewView)
        addSubview(nameLabel)
        addSubview(clickButton)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 104),
            heightAnchor.constraint(equalToConstant: 72),
            previewView.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            previewView.centerXAnchor.constraint(equalTo: centerXAnchor),
            previewView.widthAnchor.constraint(equalToConstant: 90),
            previewView.heightAnchor.constraint(equalToConstant: 38),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            nameLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 4),
            nameLabel.heightAnchor.constraint(equalToConstant: 14),
            clickButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            clickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clickButton.topAnchor.constraint(equalTo: topAnchor),
            clickButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func selectBackdrop() {
        onSelected?(backdrop)
    }
}

// MARK: - Sessions Settings Tab
