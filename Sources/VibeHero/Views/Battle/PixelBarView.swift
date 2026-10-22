import AppKit

final class PixelBarView: NSView {
    var animationsEnabled = true {
        didSet {
            guard animationsEnabled != oldValue else { return }
            if !animationsEnabled { resetAnimationState() }
            updateWarningPulse()
        }
    }
    var value: CGFloat = 0.5 {
        didSet {
            let clamped = min(max(value, 0), 1)
            if clamped != value {
                value = clamped
                return
            }
            updateFillLayers(oldValue: oldValue)
        }
    }

    var fillColor = NSColor(red: 0.0, green: 0.95, blue: 0.78, alpha: 1.0) {
        didSet {
            fillLayer.backgroundColor = fillColor.cgColor
            ghostLayer.backgroundColor = ghostFillColor().cgColor
            damageFlashLayer.backgroundColor = damageFlashColor().cgColor
        }
    }

    var trackColor = NSColor.white.withAlphaComponent(0.12) {
        didSet {
            trackLayer.backgroundColor = trackColor.cgColor
        }
    }

    var isWarning = false {
        didSet {
            guard isWarning != oldValue else {
                return
            }
            updateWarningPulse()
        }
    }

    private let trackLayer = CALayer()
    private let ghostLayer = CALayer()
    private let fillLayer = CALayer()
    private let damageFlashLayer = CALayer()
    private static let minimumDamageFlashWidth: CGFloat = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        trackLayer.backgroundColor = trackColor.cgColor
        ghostLayer.backgroundColor = ghostFillColor().cgColor
        fillLayer.backgroundColor = fillColor.cgColor
        damageFlashLayer.backgroundColor = damageFlashColor().cgColor
        damageFlashLayer.opacity = 0

        for barLayer in [trackLayer, ghostLayer, fillLayer] {
            barLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer?.addSublayer(barLayer)
        }
        layer?.addSublayer(damageFlashLayer)
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = bounds.height / 2
        for barLayer in [trackLayer, ghostLayer, fillLayer] {
            barLayer.position = CGPoint(x: 0, y: bounds.midY)
            barLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
            barLayer.cornerRadius = radius
        }
        damageFlashLayer.cornerRadius = radius
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
    }

    private func updateFillLayers(oldValue: CGFloat) {
        guard animationsEnabled else {
            resetAnimationState()
            return
        }
        let presentedGhostValue = (ghostLayer.presentation()?.value(forKeyPath: "transform.scale.x") as? NSNumber)
            .map { CGFloat(truncating: $0) }
        let visibleGhostValue = min(1, max(value, presentedGhostValue ?? oldValue))

        fillLayer.removeAllAnimations()
        ghostLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()

        guard value < oldValue else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
            CATransaction.commit()
            updateWarningPulse()
            return
        }

        let drain = CABasicAnimation(keyPath: "transform.scale.x")
        drain.fromValue = visibleGhostValue
        drain.toValue = value
        drain.beginTime = CACurrentMediaTime() + 0.04
        drain.duration = 0.24
        drain.timingFunction = CAMediaTimingFunction(name: .easeOut)
        drain.fillMode = .backwards
        drain.isRemovedOnCompletion = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        CATransaction.commit()
        ghostLayer.add(drain, forKey: "ghostDrain")
        playDamageFlash(oldValue: oldValue)
        updateWarningPulse()
    }

    static func visibleDamageWidth(oldValue: CGFloat, newValue: CGFloat, barWidth: CGFloat) -> CGFloat {
        guard oldValue > newValue, barWidth > 0 else {
            return 0
        }
        let actualWidth = (oldValue - newValue) * barWidth
        return min(barWidth, max(actualWidth, minimumDamageFlashWidth))
    }

    private func playDamageFlash(oldValue: CGFloat) {
        let flashWidth = Self.visibleDamageWidth(oldValue: oldValue, newValue: value, barWidth: bounds.width)
        guard flashWidth > 0, bounds.height > 0 else {
            return
        }

        let oldTrailingEdge = min(bounds.width, max(0, oldValue * bounds.width))
        let originX = min(bounds.width - flashWidth, max(0, oldTrailingEdge - flashWidth))
        damageFlashLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        damageFlashLayer.frame = CGRect(x: originX, y: 0, width: flashWidth, height: bounds.height)
        damageFlashLayer.opacity = 0
        CATransaction.commit()

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.95, 0.75, 0]
        flash.keyTimes = [0, 0.35, 1]
        flash.duration = 0.36
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        damageFlashLayer.add(flash, forKey: "damageFlash")
    }

    private func ghostFillColor() -> NSColor {
        guard let blended = fillColor.blended(withFraction: 0.5, of: .white) else {
            return fillColor.withAlphaComponent(0.55)
        }
        return blended.withAlphaComponent(0.55)
    }

    private func damageFlashColor() -> NSColor {
        fillColor.blended(withFraction: 0.78, of: .white) ?? .white
    }

    private func updateWarningPulse() {
        fillLayer.removeAnimation(forKey: "lowHPPulse")
        guard isWarning, animationsEnabled else {
            return
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.5
        pulse.duration = 0.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fillLayer.add(pulse, forKey: "lowHPPulse")
    }

    private func resetAnimationState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for barLayer in [trackLayer, ghostLayer, fillLayer, damageFlashLayer] {
            barLayer.removeAllAnimations()
        }
        fillLayer.transform = CATransform3DMakeScale(value, 1, 1)
        ghostLayer.transform = CATransform3DMakeScale(value, 1, 1)
        fillLayer.opacity = 1
        damageFlashLayer.opacity = 0
        CATransaction.commit()
    }
}
