import AppKit

final class ToolsSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private let hooksLabel = NSTextField(labelWithString: "")
    private let hooksDetailLabel = NSTextField(labelWithString: "")
    private let hooksStack = NSStackView()
    private var hookRows: [TokenHookRowView] = []
    private var nativeStatusTimer: Timer?

    override func loadView() {
        view = NSView()
        setup()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        nativeStatusTimer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.hookRows.filter { $0.tool.usesNativeUsage }.forEach { $0.refresh() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        nativeStatusTimer = timer
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        nativeStatusTimer?.invalidate()
        nativeStatusTimer = nil
    }

    private func setup() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
        ])

        hooksLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        hooksDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        hooksDetailLabel.textColor = .secondaryLabelColor
        hooksDetailLabel.lineBreakMode = .byWordWrapping
        hooksDetailLabel.maximumNumberOfLines = 3

        hooksStack.orientation = .vertical
        hooksStack.alignment = .leading
        hooksStack.spacing = 8

        hookRows = CodingToolHook.allCases.map { tool in
            let row = TokenHookRowView(tool: tool)
            row.onInstall = { [weak self] selectedTool in
                self?.installHook(selectedTool)
            }
            hooksStack.addArrangedSubview(row)
            // A leading-aligned vertical stack would otherwise leave each card at
            // its minimum width, squeezing the detail text.
            row.widthAnchor.constraint(equalTo: hooksStack.widthAnchor).isActive = true
            return row
        }

        let mainStack = NSStackView(views: [hooksLabel, hooksDetailLabel, hooksStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            hooksDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            hooksStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        hooksLabel.stringValue = L10n.text(.tokenHooks)
        hooksDetailLabel.stringValue = L10n.text(.tokenHooksDetail)
        hookRows.forEach { $0.refresh() }
    }

    private func installHook(_ tool: CodingToolHook) {
        do {
            try TokenHookInstaller.install(tool)
            refresh()
        } catch {
            hookRows.first { $0.tool == tool }?.showError(error.localizedDescription)
        }
    }
}

// MARK: - Helper Views

/// Scrim for a settings section that is not ready to be used yet. Sitting on top
/// of the section is what makes it work twice over: it dims the controls and, as
/// the frontmost view in that area, it takes the clicks and scrolls that would
/// otherwise reach them.
final class DevelopmentOverlayView: NSView {
    private let badgeBackground = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let detailKey: L10nKey

    init(detail: L10nKey) {
        detailKey = detail
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        badgeLabel.stringValue = L10n.text(.inDevelopment)
        detailLabel.stringValue = L10n.text(detailKey)
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.68).cgColor
        layer?.cornerRadius = 8

        badgeBackground.wantsLayer = true
        badgeBackground.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.16).cgColor
        badgeBackground.layer?.borderColor = NSColor.systemOrange.cgColor
        badgeBackground.layer?.borderWidth = 1
        badgeBackground.layer?.cornerRadius = 13
        addSubview(badgeBackground)

        badgeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textColor = .systemOrange
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.addSubview(badgeLabel)

        detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        // Badge and caption move as one block so they stay inside the scrim no
        // matter how short the section is - the equipment slots are under 100pt.
        let contentStack = NSStackView(views: [badgeBackground, detailLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        let centered = contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        // Centering reads best on a short section, but the skill tree is 500pt
        // tall - a block at its middle only shows up after a long scroll, so it
        // gives way to the cap near the top.
        centered.priority = .defaultLow

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centered,
            contentStack.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 84),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            badgeBackground.heightAnchor.constraint(equalToConstant: 26),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeBackground.leadingAnchor, constant: 14),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeBackground.trailingAnchor, constant: -14),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeBackground.centerYAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32)
        ])
    }
}

final class TokenHookRowView: NSView {
    let tool: CodingToolHook
    var onInstall: ((CodingToolHook) -> Void)?

    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton(title: "", target: nil, action: nil)

    init(tool: CodingToolHook) {
        self.tool = tool
        super.init(frame: .zero)
        setup()
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        let state = TokenHookInstaller.state(for: tool)
        nameLabel.stringValue = tool.displayName
        detailLabel.stringValue = state.detail
        if state.isAutomatic {
            statusLabel.stringValue = state.hasUsageData ? "✓" : "…"
            statusLabel.toolTip = L10n.text(state.hasUsageData ? .nativeReceiving : .nativeWaiting)
            statusLabel.textColor = state.hasUsageData ? .systemGreen : .secondaryLabelColor
            installButton.title = L10n.text(.nativeAutomatic)
            installButton.isEnabled = false
            return
        }
        setInstalledMarker(state.isInstalled)
        installButton.title = state.isInstalled ? L10n.text(.hookInstalled) : L10n.text(.installHook)
        installButton.isEnabled = !state.isInstalled
    }

    func showError(_ message: String) {
        detailLabel.stringValue = L10n.string(.hookInstallFailed, message)
        setInstalledMarker(false)
        installButton.title = L10n.text(.installHook)
        installButton.isEnabled = true
    }

    /// The button title already spells out "Installed", so the row only needs a
    /// glance marker beside it - a second green "Installed" label was wide
    /// enough to be drawn on top of the detail text.
    private func setInstalledMarker(_ isInstalled: Bool) {
        statusLabel.stringValue = isInstalled ? "✓" : ""
        statusLabel.toolTip = isInstalled ? L10n.text(.hookInstalled) : nil
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.alignment = .center

        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(install)
        // Without this the row's spare width lands in the button, stretching a
        // one-word title across half the card.
        installButton.setContentHuggingPriority(.required, for: .horizontal)

        [nameLabel, detailLabel, statusLabel, installButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Fits one detail line snugly and grows when the text wraps.
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 420),

            // Right column: install button with the status marker next to it.
            installButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            installButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            statusLabel.trailingAnchor.constraint(equalTo: installButton.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: installButton.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 16),

            // Text column ends before the marker instead of running under it.
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
    }

    @objc private func install() {
        guard !tool.usesNativeUsage else { return }
        onInstall?(tool)
    }
}
