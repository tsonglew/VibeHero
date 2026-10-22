import AppKit

extension NotchContentView {
    func updateCampUI() {
        let action = L10n.text(isCamping ? .campLeave : .campEnter)
        let rules = L10n.text(.campRules)
        campButton.image = NSImage(systemSymbolName: isCamping ? "play.circle.fill" : "tent",
                                   accessibilityDescription: action)
        campButton.state = isCamping ? .on : .off
        campButton.contentTintColor = isCamping
            ? NSColor(red: 0.62, green: 0.84, blue: 0.72, alpha: 1)
            : .white.withAlphaComponent(0.82)
        campButton.toolTip = action + "\n" + rules
        campButton.setAccessibilityLabel(action)
        campButton.setAccessibilityHelp(rules)
        campButton.setAccessibilityValue(isCamping ? 1 : 0)
        compactStatusLabel.toolTip = isCamping ? rules : nil
    }

    /// Persistent encounter state has its own line. Rewards and transient
    /// combat messages keep their separate status area below the scene.
    func refreshEncounterPresentation(now: Date = Date()) {
        updateCampUI()
        let presentation = encounterPresentation(now: now)
        var statuses: [String] = []
        var explanations: [String] = []

        if isCamping {
            statuses.append(L10n.text(isDefeated ? .campRecovering : .campResting))
            explanations.append(L10n.text(.campRules))
        } else {
            if presentation.shieldMaximum > 0 {
                statuses.append(L10n.string(.monsterShieldStatus,
                                           Double(presentation.shieldRemaining),
                                           Double(presentation.shieldMaximum)))
                explanations.append(L10n.text(.monsterShieldDetails))
            }
            if presentation.idleRegenerationFractionPerSecond > 0 {
                let key: L10nKey = presentation.idleRegenerationActive
                    ? .monsterRegenerationStatus : .monsterRegenerationPausedStatus
                statuses.append(L10n.string(key, Double(presentation.idleRegenerationFractionPerSecond * 100)))
                explanations.append(L10n.text(.monsterRegenerationDetails))
            }
            if let phase = presentation.bossPhase {
                statuses.append(phase >= 2
                    ? L10n.string(.bossPhase2Status, Int(((monsterMechanics.attackMultiplier - 1) * 100).rounded()))
                    : L10n.text(.bossPhase1Status))
                explanations.append(L10n.text(.bossPhaseDetails))
            }
        }

        let status = statuses.joined(separator: " · ")
        mechanicLabel.stringValue = status
        mechanicLabel.isHidden = status.isEmpty
        mechanicLabel.textColor = isCamping
            ? NSColor(red: 0.62, green: 0.84, blue: 0.72, alpha: 1)
            : presentation.bossPhase == 2
                ? NSColor(red: 1, green: 0.69, blue: 0.57, alpha: 1)
                : .white.withAlphaComponent(0.86)
        mechanicLabel.toolTip = ([status] + explanations).joined(separator: "\n")
        mechanicLabel.setAccessibilityLabel(status)
        mechanicLabel.setAccessibilityHelp(explanations.joined(separator: "\n"))
    }
}
