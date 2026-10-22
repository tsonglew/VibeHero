import AppKit

final class GameSettingsTab: NSViewController {
    var onRoleChanged: (() -> Void)?
    var onSkillChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()

    private let roleLabel = NSTextField(labelWithString: "")
    private let roleDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let rolePerkLabel = NSTextField(wrappingLabelWithString: "")
    private(set) var roleChoiceViews: [RoleChoiceView] = []
    private let skillTreeView = SkillTreeView()
    private let skillTreeLabel = NSTextField(labelWithString: "")

    override func loadView() {
        view = NSView()
        setup()
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
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            // Pinning the bottom too would cap the document at the viewport, which
            // clipped the 500pt skill module with no way to scroll to it. Filling
            // the viewport is the minimum; taller content scrolls.
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])
        roleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        roleDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        roleDetailLabel.textColor = .secondaryLabelColor
        roleDetailLabel.lineBreakMode = .byWordWrapping
        roleDetailLabel.maximumNumberOfLines = 0
        rolePerkLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        rolePerkLabel.textColor = .secondaryLabelColor
        rolePerkLabel.lineBreakMode = .byWordWrapping
        rolePerkLabel.maximumNumberOfLines = 0

        let roleGridStack = NSStackView()
        roleGridStack.orientation = .vertical
        roleGridStack.alignment = .leading
        roleGridStack.spacing = 8

        roleChoiceViews = HeroRole.allCases.map { role in
            let choiceView = RoleChoiceView(role: role)
            choiceView.onSelected = { [weak self] selectedRole in
                self?.selectRole(selectedRole)
            }
            return choiceView
        }

        for rowStart in stride(from: 0, to: roleChoiceViews.count, by: 3) {
            let rowViews = Array(roleChoiceViews[rowStart..<min(rowStart + 3, roleChoiceViews.count)])
            let rowStack = NSStackView(views: rowViews)
            rowStack.orientation = .horizontal
            rowStack.alignment = .top
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            roleGridStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: roleGridStack.widthAnchor).isActive = true
        }

        let roleStack = NSStackView(views: [roleLabel, roleGridStack, roleDetailLabel, rolePerkLabel])
        roleStack.orientation = .vertical
        roleStack.alignment = .leading
        roleStack.spacing = 8

        // Skill Tree
        skillTreeView.onSkillChanged = { [weak self] in
            self?.onSkillChanged?()
        }
        skillTreeView.translatesAutoresizingMaskIntoConstraints = false
        skillTreeView.heightAnchor.constraint(equalToConstant: 760).isActive = true

        let skillTreeContainer = skillTreeView

        skillTreeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        skillTreeLabel.stringValue = L10n.text(.skills)

        let skillTreeStack = NSStackView(views: [skillTreeLabel, skillTreeContainer])
        skillTreeStack.orientation = .vertical
        skillTreeStack.alignment = .leading
        skillTreeStack.spacing = 8

        // Main stack
        let mainStack = NSStackView(views: [
            roleStack,
            makeSeparator(),
            skillTreeStack
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
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: mainStack.bottomAnchor, constant: 24),
            skillTreeContainer.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            roleStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            roleGridStack.widthAnchor.constraint(equalTo: roleStack.widthAnchor),
            roleDetailLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            rolePerkLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        refresh()
    }

    func refresh() {
        roleLabel.stringValue = L10n.text(.heroRole)

        let selectedRole = HeroRole.load()
        roleChoiceViews.forEach { $0.refresh(selectedRole: selectedRole) }
        updateRoleDetails(for: selectedRole)

        skillTreeView.refresh()
        skillTreeLabel.stringValue = L10n.text(.skills)
    }

    private func updateRoleDetails(for role: HeroRole) {
        roleDetailLabel.stringValue = role.detail
        rolePerkLabel.stringValue = role.perk
    }

    private func selectRole(_ role: HeroRole) {
        role.save()
        refresh()
        onRoleChanged?()
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}

// MARK: - Equipment Settings Tab
