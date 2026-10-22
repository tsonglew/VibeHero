import AppKit

// MARK: - Session List View

/// Flipped so the scrolled rows stack downward from the top.
private final class SessionRowsView: NSView {
    override var isFlipped: Bool { true }
}

/// Frame-based list, deliberately not Auto Layout.
///
/// The notch HUD positions all of its children with explicit frames, and an
/// `NSStackView` of rows wanted ~245pt inside a 92pt slot, so Auto Layout
/// resolved the conflict by compressing every arranged subview: the header and
/// the last rows ended up 0pt tall and the HUD rendered an empty dark box even
/// though the rows existed and were not hidden. Laying the rows out by hand
/// keeps every row at full height.
///
/// The header stays pinned and the rows live in a scroll view: the HUD grows
/// the notch panel toward `preferredContentHeight`, and anything that still
/// does not fit scrolls instead of disappearing.
final class SessionListView: NSView {
    private enum Metrics {
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 4
        static let headerHeight: CGFloat = 12
        static let headerGap: CGFloat = 3
        static let rowHeight: CGFloat = 17
        static let rowGap: CGFloat = 2
        static let overflowHeight: CGFloat = 11
        static let emptyHeight: CGFloat = 14
        /// Rows are cheap but not free, and a list this long is a browser, not a
        /// glance; the tail collapses into "+N more" and the header still
        /// reports the true total.
        static let maxRows = 60
    }

    private let headerLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private let overflowLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let rowsView = SessionRowsView()
    private var rowViews: [SessionRowView] = []
    private var sessions: [IDESession] = []
    private var displayedIds: [String] = []

    /// Height at which nothing has to scroll. The HUD asks for this much room
    /// for the panel and settles for less.
    var preferredContentHeight: CGFloat {
        intrinsicContentSize.height
    }

    // Top-down coordinates make the list layout read in the order it draws.
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        // Dark background matching HUD style
        layer?.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 0.95).cgColor
        layer?.cornerRadius = 8
        clipsToBounds = true

        headerLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        headerLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        emptyLabel.font = .systemFont(ofSize: 11)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.5)

        overflowLabel.font = .systemFont(ofSize: 9)
        overflowLabel.textColor = NSColor.white.withAlphaComponent(0.45)

        for label in [headerLabel, emptyLabel, overflowLabel] {
            label.maximumNumberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
        }
        // Set before the first scan lands so the empty state is not a blank card.
        emptyLabel.stringValue = L10n.text(.noActiveSessions)
        addSubview(headerLabel)
        addSubview(emptyLabel)

        // Overlay scrollers so the rows keep the full width when idle.
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = rowsView
        addSubview(scrollView)

        rowsView.addSubview(overflowLabel)
    }

    func updateSessions(_ sessions: [IDESession]) {
        let rowSessions = Array(sessions.prefix(Metrics.maxRows))
        let ids = rowSessions.map(\.id)

        self.sessions = sessions
        headerLabel.stringValue = headerText(for: sessions)
        emptyLabel.stringValue = L10n.text(.noActiveSessions)

        // Reuse the existing rows whenever the roster is unchanged - a reorder
        // is handled by re-applying content per index, so only a membership or
        // count change needs to rebuild.
        if Set(ids) == Set(displayedIds), rowViews.count == rowSessions.count {
            for (index, session) in rowSessions.enumerated() {
                rowViews[index].update(session: session)
            }
        } else {
            rowViews.forEach { $0.removeFromSuperview() }
            rowViews = rowSessions.map { session in
                let row = SessionRowView(session: session)
                rowsView.addSubview(row)
                return row
            }
        }

        displayedIds = ids
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Re-render the cached roster immediately when the app language changes;
    /// waiting for a monitor scan left existing rows in the previous language.
    func reloadLocalization() {
        updateSessions(sessions)
    }

    /// Total plus a per-agent breakdown, so a mixed list says which agents it is
    /// made of before any row is read. Agent names are product names and stay in
    /// English in every language, like they do in the tools tab. The header
    /// truncates at the tail in the narrow HUD, which keeps the total visible.
    private func headerText(for sessions: [IDESession]) -> String {
        let total = L10n.string(.sessionCount, sessions.count)
        guard sessions.count > 1 else {
            return total
        }

        let breakdown = IDEType.allCases.compactMap { ide -> String? in
            let count = sessions.filter { $0.ide == ide }.count
            return count > 0 ? "\(ide.displayName) \(count)" : nil
        }

        // A single agent is already spelled out on every row.
        guard breakdown.count > 1 else {
            return total
        }
        return total + " · " + breakdown.joined(separator: " · ")
    }

    /// Full height of the list with nothing scrolled away. The HUD reads this
    /// through `preferredContentHeight` to size the expanded panel, and the
    /// settings window uses it directly, where the list is driven by Auto Layout
    /// inside a scroll view with no height of its own.
    override var intrinsicContentSize: NSSize {
        let vertical = Metrics.verticalInset * 2

        guard !sessions.isEmpty else {
            return NSSize(width: NSView.noIntrinsicMetric, height: vertical + Metrics.emptyHeight)
        }

        var height = vertical + Metrics.headerHeight
        if !rowViews.isEmpty {
            height += Metrics.headerGap
            height += CGFloat(rowViews.count) * Metrics.rowHeight
            height += CGFloat(rowViews.count - 1) * Metrics.rowGap
        }
        if sessions.count > rowViews.count {
            height += Metrics.rowGap + Metrics.overflowHeight
        }

        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func layout() {
        super.layout()

        let inset = Metrics.horizontalInset
        let contentWidth = max(0, bounds.width - inset * 2)
        var y = Metrics.verticalInset

        guard !sessions.isEmpty else {
            headerLabel.isHidden = true
            scrollView.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.frame = NSRect(x: inset, y: y, width: contentWidth, height: Metrics.emptyHeight)
            return
        }

        emptyLabel.isHidden = true
        headerLabel.isHidden = false
        scrollView.isHidden = false
        headerLabel.frame = NSRect(x: inset, y: y, width: contentWidth, height: Metrics.headerHeight)
        y += Metrics.headerHeight + Metrics.headerGap

        let scrollHeight = max(0, bounds.height - Metrics.verticalInset - y)
        scrollView.frame = NSRect(x: inset, y: y, width: contentWidth, height: scrollHeight)
        layoutRows(width: contentWidth, visibleHeight: scrollHeight)
    }

    /// Lays the rows out inside the scrolled document view. The document is
    /// never shorter than the clip view: an undersized flipped document would be
    /// parked at the bottom of the (unflipped) clip view, leaving the rows
    /// floating below the header.
    private func layoutRows(width: CGFloat, visibleHeight: CGFloat) {
        var y: CGFloat = 0

        for row in rowViews {
            row.frame = NSRect(x: 0, y: y, width: width, height: Metrics.rowHeight)
            y += Metrics.rowHeight + Metrics.rowGap
        }

        let remaining = sessions.count - rowViews.count
        if remaining > 0 {
            overflowLabel.isHidden = false
            overflowLabel.stringValue = L10n.string(.moreSessions, remaining)
            overflowLabel.frame = NSRect(x: 0, y: y, width: width, height: Metrics.overflowHeight)
            y += Metrics.overflowHeight
        } else {
            overflowLabel.isHidden = true
            y = max(0, y - Metrics.rowGap)
        }

        rowsView.frame = NSRect(x: 0, y: 0, width: width, height: max(y, visibleHeight))

        // The panel grows to fit, so a list that needed scrolling a moment ago
        // may fit now; scroll back to the top so the header is not left above a
        // stale offset with empty space under the last row.
        if y <= visibleHeight, scrollView.contentView.bounds.origin.y != 0 {
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

final class SessionRowView: NSView {
    private enum Metrics {
        static let iconWidth: CGFloat = 16
        @MainActor static var statusWidth: CGFloat {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8)]
            return max(46, [L10n.text(.sessionActive), L10n.text(.sessionIdle)]
                .map { ($0 as NSString).size(withAttributes: attributes).width }
                .max() ?? 0).rounded(.up)
        }
        static let tokenWidth: CGFloat = 44
        static let gap: CGFloat = 6
        static let agentHeight: CGFloat = 13
        static let agentPadding: CGFloat = 5

        @MainActor static let agentFont = NSFont.systemFont(ofSize: 9, weight: .semibold)

        /// One column wide enough for every agent name: the tags line up down the
        /// list, and none of them gets truncated to something unreadable like
        /// "Claude C…" - telling the agents apart is the whole point of the tag.
        /// Measured through a field built by the same factory as the real tag: a
        /// label configured for truncation reports a wider fit than a bare one,
        /// and measuring the bare one is what clipped "Claude Code".
        @MainActor static let agentWidth: CGFloat = {
            let ruler = SessionRowView.makeAgentLabel()
            let widest = IDEType.allCases
                .map { ide -> CGFloat in
                    ruler.stringValue = ide.displayName
                    return ruler.fittingSize.width
                }
                .max() ?? 0
            return (widest + agentPadding * 2).rounded(.up)
        }()
    }

    private static func makeAgentLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = Metrics.agentFont
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private let iconLabel = NSTextField(labelWithString: "")
    private let agentChip = NSView()
    private let agentLabel = SessionRowView.makeAgentLabel()
    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let tokenLabel = NSTextField(labelWithString: "")

    init(session: IDESession) {
        super.init(frame: .zero)
        setup()
        update(session: session)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        iconLabel.font = .systemFont(ofSize: 12)

        agentChip.wantsLayer = true
        agentChip.layer?.cornerRadius = 4
        addSubview(agentChip)
        agentChip.addSubview(agentLabel)

        nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.font = .systemFont(ofSize: 8)

        tokenLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        tokenLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        tokenLabel.alignment = .right

        for label in [iconLabel, nameLabel, statusLabel, tokenLabel] {
            label.maximumNumberOfLines = 1
            addSubview(label)
        }
    }

    override func layout() {
        super.layout()

        func centeredY(_ height: CGFloat) -> CGFloat {
            ((bounds.height - height) / 2).rounded()
        }

        iconLabel.frame = NSRect(x: 0, y: centeredY(14), width: Metrics.iconWidth, height: 14)
        tokenLabel.frame = NSRect(
            x: max(0, bounds.width - Metrics.tokenWidth),
            y: centeredY(11),
            width: Metrics.tokenWidth,
            height: 11
        )
        statusLabel.frame = NSRect(
            x: max(0, tokenLabel.frame.minX - Metrics.gap - Metrics.statusWidth),
            y: centeredY(10),
            width: Metrics.statusWidth,
            height: 10
        )

        agentChip.frame = NSRect(
            x: iconLabel.frame.maxX + Metrics.gap,
            y: centeredY(Metrics.agentHeight),
            width: Metrics.agentWidth,
            height: Metrics.agentHeight
        )
        agentLabel.frame = NSRect(
            x: Metrics.agentPadding,
            y: ((Metrics.agentHeight - 11) / 2).rounded(),
            width: Metrics.agentWidth - Metrics.agentPadding * 2,
            height: 11
        )

        let nameX = agentChip.frame.maxX + Metrics.gap
        nameLabel.frame = NSRect(
            x: nameX,
            y: centeredY(12),
            width: max(0, statusLabel.frame.minX - Metrics.gap - nameX),
            height: 12
        )
    }

    func update(session: IDESession) {
        // The icon and the agent tag live here rather than in setup so a reordered
        // roster can be re-applied per index without rebuilding the row views.
        iconLabel.stringValue = session.ide.icon
        agentLabel.stringValue = session.ide.displayName
        agentLabel.textColor = session.ide.color
        agentChip.layer?.backgroundColor = session.ide.color.withAlphaComponent(0.16).cgColor
        nameLabel.stringValue = session.isUnattributed ? L10n.text(.sessionUnknownProject) : session.displayName
        let project = session.isUnattributed ? L10n.text(.sessionUnknownProject) : session.projectPath
        nameLabel.toolTip = "\(session.ide.displayName) · \(project)"
        let isActive = session.isActive
        statusLabel.stringValue = L10n.text(isActive ? .sessionActive : .sessionIdle)
        statusLabel.textColor = isActive
            ? NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1)
            : NSColor.white.withAlphaComponent(0.4)
        if let tokenCount = session.tokenCount {
            tokenLabel.stringValue = formatTokens(tokenCount)
            tokenLabel.toolTip = nil
            tokenLabel.setAccessibilityLabel(nil)
        } else {
            tokenLabel.stringValue = L10n.text(.sessionUnknownTokenCount)
            tokenLabel.toolTip = L10n.text(.sessionUnknownTokenUsage)
            tokenLabel.setAccessibilityLabel(L10n.text(.sessionUnknownTokenUsage))
        }
        needsLayout = true
    }

    private func formatTokens(_ count: Int) -> String {
        // Token counts: abbreviated with K/M
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
