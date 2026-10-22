import AppKit

final class GeneralSettingsTab: NSViewController {
    var onLanguageChanged: (() -> Void)?
    var onDisplayChanged: (() -> Void)?
    var onFullScreenHideChanged: (() -> Void)?
    var onBackdropChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()

    // UI Elements
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let displayLabel = NSTextField(labelWithString: "")
    private let displayPopup = NSPopUpButton()
    private let displayDetailLabel = NSTextField(labelWithString: "")
    private let fullScreenLabel = NSTextField(labelWithString: "")
    private let fullScreenToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fullScreenDetailLabel = NSTextField(labelWithString: "")
    private let backdropLabel = NSTextField(labelWithString: "")
    private var backdropChoiceViews: [BackdropChoiceView] = []
    private var displayIDs: [Int?] = []

    override func loadView() {
        view = NSView()
        setup()
    }

    private func setup() {
        // Setup scroll view
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

        // Style labels
        languageLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        displayLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        fullScreenLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        backdropLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        [displayDetailLabel, fullScreenDetailLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
            $0.lineBreakMode = .byWordWrapping
            $0.maximumNumberOfLines = 2
        }

        // Language
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)

        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .vertical
        languageStack.alignment = .leading
        languageStack.spacing = 8
        languagePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        // Display
        displayPopup.target = self
        displayPopup.action = #selector(displayChanged)

        let displayStack = NSStackView(views: [displayLabel, displayPopup, displayDetailLabel])
        displayStack.orientation = .vertical
        displayStack.alignment = .leading
        displayStack.spacing = 8
        displayPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        // Full Screen
        fullScreenToggle.target = self
        fullScreenToggle.action = #selector(fullScreenHideChanged)

        let fullScreenStack = NSStackView(views: [fullScreenLabel, fullScreenToggle, fullScreenDetailLabel])
        fullScreenStack.orientation = .vertical
        fullScreenStack.alignment = .leading
        fullScreenStack.spacing = 8

        // Backdrop
        let backdropRowStack = NSStackView()
        backdropRowStack.orientation = .horizontal
        backdropRowStack.alignment = .top
        backdropRowStack.spacing = 8

        backdropChoiceViews = BattleBackdrop.allCases.map { backdrop in
            let choiceView = BackdropChoiceView(backdrop: backdrop)
            choiceView.onSelected = { [weak self] selectedBackdrop in
                self?.selectBackdrop(selectedBackdrop)
            }
            backdropRowStack.addArrangedSubview(choiceView)
            return choiceView
        }

        let backdropStack = NSStackView(views: [backdropLabel, backdropRowStack])
        backdropStack.orientation = .vertical
        backdropStack.alignment = .leading
        backdropStack.spacing = 8

        // Main stack
        let mainStack = NSStackView(views: [
            languageStack,
            makeSeparator(),
            displayStack,
            makeSeparator(),
            fullScreenStack,
            makeSeparator(),
            backdropStack
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            displayDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            fullScreenDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        languageLabel.stringValue = L10n.text(.language)
        displayLabel.stringValue = L10n.text(.display)
        fullScreenLabel.stringValue = L10n.text(.fullScreen)
        fullScreenToggle.title = L10n.text(.hideInFullScreen)
        fullScreenDetailLabel.stringValue = L10n.text(.hideInFullScreenDetail)
        backdropLabel.stringValue = L10n.text(.backdrop)

        // Language options
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map(\.displayName))
        let selectedLanguage = AppLanguage.load()
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: selectedLanguage) ?? 0)

        // Display options
        let screens = NSScreen.screens
        displayIDs = [nil] + screens.map(\.notchDisplayID)
        displayPopup.removeAllItems()
        displayPopup.addItem(withTitle: L10n.text(.followActiveDisplay))
        screens.forEach { screen in
            displayPopup.addItem(withTitle: screen.notchDisplayName)
        }

        let selectedDisplayID = ScreenPinning.load()
        if let selectedDisplayID,
           let index = screens.firstIndex(where: { $0.notchDisplayID == selectedDisplayID }) {
            displayPopup.selectItem(at: index + 1)
            displayDetailLabel.stringValue = L10n.string(.fixedToDisplay, screens[index].notchDisplayName)
        } else {
            displayPopup.selectItem(at: 0)
            displayDetailLabel.stringValue = selectedDisplayID == nil
                ? L10n.text(.followsActiveDisplay)
                : L10n.text(.pinnedDisplayMissing)
        }

        // Full screen toggle
        fullScreenToggle.state = FullScreenHidePreference.load() ? .on : .off

        // Backdrop
        backdropChoiceViews.forEach { $0.refreshSelection() }
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard AppLanguage.allCases.indices.contains(index) else { return }
        AppLanguage.save(AppLanguage.allCases[index])
        refresh()
        onLanguageChanged?()
    }

    @objc private func displayChanged() {
        let index = displayPopup.indexOfSelectedItem
        let selectedDisplayID = displayIDs.indices.contains(index) ? displayIDs[index] : nil
        ScreenPinning.save(selectedDisplayID)
        refresh()
        onDisplayChanged?()
    }

    @objc private func fullScreenHideChanged() {
        FullScreenHidePreference.save(fullScreenToggle.state == .on)
        onFullScreenHideChanged?()
    }

    private func selectBackdrop(_ backdrop: BattleBackdrop) {
        backdrop.save()
        refresh()
        onBackdropChanged?()
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}

// MARK: - Game Settings Tab
