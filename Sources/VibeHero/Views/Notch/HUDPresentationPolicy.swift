import Foundation

/// Presentation never determines whether earned combat work is processed.
/// Visibility and motion preferences only choose what the user can see move.
struct HUDPresentationPolicy: Equatable {
    let isVisible: Bool
    let isExpanded: Bool
    let showsSessions: Bool
    let reduceMotion: Bool
    let isCamping: Bool

    init(isVisible: Bool, isExpanded: Bool, showsSessions: Bool, reduceMotion: Bool, isCamping: Bool = false) {
        self.isVisible = isVisible
        self.isExpanded = isExpanded
        self.showsSessions = showsSessions
        self.reduceMotion = reduceMotion
        self.isCamping = isCamping
    }

    var showsBattle: Bool { isVisible && isExpanded && !showsSessions }
    var animatesBattle: Bool { showsBattle && !reduceMotion && !isCamping }
    var animatesCompact: Bool { isVisible && !isExpanded && !reduceMotion && !isCamping }
    var animatesWindow: Bool { isVisible && !reduceMotion && !isCamping }
}
