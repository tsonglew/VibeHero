import AppKit

final class EquipmentSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = EquipmentDocumentView()
    private let balanceLabel = NSTextField(labelWithString: "")
    private let boostLabel = NSTextField(wrappingLabelWithString: "")
    private let equipmentLabel = NSTextField(labelWithString: "")
    private let rulesLabel = NSTextField(wrappingLabelWithString: "")
    private let historyLabel = NSTextField(labelWithString: "")
    private let historyStack = NSStackView()
    private let emptyHistoryLabel = NSTextField(wrappingLabelWithString: "")
    private let now: () -> Date
    private var observations: EquipmentObservations?
    private(set) var equipmentRows: [EquipmentRowView] = []
    private(set) var refreshTimer: Timer?

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView()
        setup()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        guard observations == nil else { return }
        let tokens = [Notification.Name.vibeHeroInventoryChanged, .notchHeroLanguageChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        observations = EquipmentObservations(tokens: tokens)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                guard self.refreshTimer?.isValid == true else { return }
                self.refreshBoost()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
        observations = nil
    }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])

        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        for label in [equipmentLabel, historyLabel] { label.font = .systemFont(ofSize: 13, weight: .semibold) }
        for label in [boostLabel, rulesLabel, emptyHistoryLabel] {
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
        }
        equipmentRows = EquipmentSlot.allCases.map { slot in
            let row = EquipmentRowView(slot: slot, now: now)
            row.onChanged = { [weak self] in self?.refresh() }
            return row
        }
        historyStack.orientation = .vertical
        historyStack.alignment = .leading
        historyStack.spacing = 10
        let children: [NSView] = [balanceLabel, boostLabel, equipmentLabel] + equipmentRows + [rulesLabel, historyLabel, emptyHistoryLabel, historyStack]
        let mainStack = NSStackView(views: children)
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: mainStack.bottomAnchor, constant: 24)
        ])
        for child in children {
            child.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }
        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }
        balanceLabel.stringValue = L10n.string(.equipmentGoldBalance, ItemSystem.gold.formatted())
        equipmentLabel.stringValue = L10n.text(.equipmentSectionTitle)
        rulesLabel.stringValue = L10n.text(.equipmentRules)
        historyLabel.stringValue = L10n.text(.equipmentRecentRewards)
        emptyHistoryLabel.stringValue = L10n.text(.equipmentHistoryEmpty)
        equipmentRows.forEach { $0.refresh() }
        refreshBoost()
        refreshHistory()
    }

    private func refreshBoost() {
        let remaining = ItemSystem.powerBoostRemaining(now: now())
        boostLabel.stringValue = remaining > 0
            ? L10n.string(.equipmentBoostActive, Int(((ItemSystem.powerBoostMultiplier - 1) * 100).rounded()), remaining)
            : L10n.text(.equipmentBoostInactive)
    }

    private func refreshHistory() {
        historyStack.arrangedSubviews.forEach { historyStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let records = Array(ItemSystem.recentRewards.prefix(40))
        emptyHistoryLabel.isHidden = !records.isEmpty
        historyStack.isHidden = records.isEmpty
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.load().rawValue)
        formatter.setLocalizedDateFormatFromTemplate("MMMd jm")
        for record in records {
            let title = NSTextField(wrappingLabelWithString: Self.rewardText(record))
            title.font = .systemFont(ofSize: 11)
            let timestamp = NSTextField(labelWithString: formatter.string(from: record.timestamp))
            timestamp.font = .systemFont(ofSize: 10)
            timestamp.textColor = .secondaryLabelColor
            let row = NSStackView(views: [title, timestamp])
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 3
            historyStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true
            title.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        }
    }

    static func rewardText(_ record: RewardRecord) -> String {
        switch record.kind {
        case .healthPotion:
            let restored = record.healedHP ?? Double(record.amount)
            return L10n.string(.equipmentHistoryPotion, restored.formatted(.number.precision(.fractionLength(0...1))))
        case .powerBoost: return L10n.string(.equipmentHistoryBoost, record.amount)
        case .gold: return L10n.string(.equipmentHistoryGold, record.amount)
        case .bossGold: return L10n.string(.equipmentHistoryBossGold, record.amount)
        case .equipmentEquipped, .equipmentSalvaged, .equipmentUpgraded:
            guard let slot = record.slot, let rarity = record.rarity else { return L10n.text(.lootEquipment) }
            let name = EquipmentDrop(slot: slot, rarity: rarity).displayName
            switch record.kind {
            case .equipmentEquipped: return L10n.string(.equipmentEquipped, name)
            case .equipmentSalvaged: return L10n.string(.equipmentSalvaged, name, record.amount)
            default: return L10n.string(.equipmentHistoryUpgrade, name, record.amount)
            }
        }
    }
}

/// Own observer tokens so releasing a controller also releases its subscriptions.
private final class EquipmentObservations: @unchecked Sendable {
    let tokens: [NSObjectProtocol]
    init(tokens: [NSObjectProtocol]) { self.tokens = tokens }
    deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}

private final class EquipmentDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class EquipmentRowView: NSView {
    let slot: EquipmentSlot
    var onChanged: (() -> Void)?
    private let now: () -> Date
    private let slotLabel = NSTextField(labelWithString: "")
    private let currentLabel = NSTextField(wrappingLabelWithString: "")
    private let nextLabel = NSTextField(wrappingLabelWithString: "")
    private let reasonLabel = NSTextField(wrappingLabelWithString: "")
    let upgradeButton = NSButton()

    init(slot: EquipmentSlot, now: @escaping () -> Date = { Date() }) {
        self.slot = slot
        self.now = now
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        let offer = ItemSystem.upgradeOffer(for: slot)
        slotLabel.stringValue = slot.name
        currentLabel.stringValue = offer.currentRarity.map {
            L10n.string(.equipmentCurrentState, $0.name, detailedBonus(for: $0))
        } ?? L10n.text(.equipmentSlotEmpty)
        nextLabel.stringValue = offer.nextRarity.map {
            L10n.string(.equipmentNextState, $0.name, detailedBonus(for: $0))
        } ?? ""
        nextLabel.isHidden = offer.nextRarity == nil
        upgradeButton.title = offer.cost.map { L10n.string(.equipmentUpgradePrice, $0.formatted()) } ?? L10n.text(.equipmentUpgradeAction)
        switch offer.status {
        case .available:
            reasonLabel.stringValue = ""
            upgradeButton.isEnabled = true
        case .empty:
            reasonLabel.stringValue = L10n.text(.equipmentEmptyReason)
            upgradeButton.isEnabled = false
        case .maxed:
            reasonLabel.stringValue = L10n.text(.equipmentMaxedReason)
            upgradeButton.isEnabled = false
        case .insufficientGold:
            reasonLabel.stringValue = L10n.string(.equipmentInsufficientGold, max(0, (offer.cost ?? 0) - offer.balance).formatted())
            upgradeButton.isEnabled = false
        }
        reasonLabel.isHidden = reasonLabel.stringValue.isEmpty
        upgradeButton.toolTip = reasonLabel.stringValue.isEmpty ? nil : reasonLabel.stringValue
        if let next = offer.nextRarity, let cost = offer.cost {
            upgradeButton.setAccessibilityLabel(L10n.string(.equipmentUpgradeAccessibility, slot.name, next.name, cost.formatted()))
        } else {
            upgradeButton.setAccessibilityLabel(L10n.string(.equipmentUnavailableAccessibility, slot.name, reasonLabel.stringValue))
        }
    }

    private func detailedBonus(for rarity: ItemRarity) -> String {
        let key: L10nKey
        switch slot {
        case .weapon: key = .equipmentDetailedWeapon
        case .armor: key = .equipmentDetailedArmor
        case .charm: key = .equipmentDetailedCharm
        }
        return L10n.string(key, slot.bonusPercent(for: rarity))
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.fillColor = .controlBackgroundColor
        box.borderColor = .separatorColor
        box.cornerRadius = 8
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        slotLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        for label in [currentLabel, nextLabel, reasonLabel] { label.font = .systemFont(ofSize: 11) }
        nextLabel.textColor = .secondaryLabelColor
        reasonLabel.textColor = .secondaryLabelColor
        upgradeButton.bezelStyle = .rounded
        upgradeButton.target = self
        upgradeButton.action = #selector(upgrade)
        let children: [NSView] = [slotLabel, currentLabel, nextLabel, reasonLabel, upgradeButton]
        let stack = NSStackView(views: children)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
            box.topAnchor.constraint(equalTo: topAnchor),
            box.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: box.contentView!.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor, constant: -10)
        ])
        for label in [slotLabel, currentLabel, nextLabel, reasonLabel] {
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    @objc private func upgrade() {
        _ = ItemSystem.upgradeEquipment(in: slot, now: now())
        refresh()
        onChanged?()
    }
}
