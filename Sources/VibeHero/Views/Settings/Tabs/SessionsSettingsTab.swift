import AppKit

final class SessionsSettingsTab: NSViewController {
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let sessionListView = SessionListView()
    private let monitor: SessionMonitor
    private(set) var refreshTimer: Timer?

    init(monitor: SessionMonitor = .shared) {
        self.monitor = monitor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        startMonitoring()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        view.addSubview(scrollView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        sessionListView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sessionListView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            // The clip view is not flipped, so a document view shorter than the
            // viewport sits at its bottom edge - that is what left a screen of
            // blank space above the list. Filling the viewport pins it to the top,
            // and taller content still scrolls.
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sessionListView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            sessionListView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sessionListView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: sessionListView.bottomAnchor, constant: 16)
        ])

        refresh()
    }

    private func startMonitoring() {
        guard refreshTimer == nil else { return }
        monitor.addObserver(self) { [weak self] sessions in
            self?.sessionListView.updateSessions(sessions)
        }
        monitor.startMonitoring()

        // Only a visible tab polls. Reappearing installs exactly one timer and
        // requests a fresh projection immediately, even if the roster is empty.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            // Created on the main actor, so this timer belongs to the main run loop.
            MainActor.assumeIsolated {
                guard self.refreshTimer?.isValid == true else { return }
                self.monitor.refreshIfNeeded()
            }
        }
    }

    func refresh() {
        titleLabel.stringValue = L10n.text(.activeSessions)
        sessionListView.reloadLocalization()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
        monitor.removeObserver(self)
    }
}
