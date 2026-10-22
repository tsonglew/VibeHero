import AppKit

/// Long-lived shape layers that combat effects reuse across replays.
///
/// These effects fire several times a second while tokens are flowing, so they
/// keep one layer per element and re-path it rather than allocating a fresh
/// layer per hit. Grouping them here keeps `BattleSceneView` from carrying ten
/// separate layer properties, and lets the effect code live in extensions
/// (Swift forbids stored properties there).
final class EffectLayerPool {
    // Hero energy laser
    let laserCore = CAShapeLayer()
    let laserGlow = CAShapeLayer()
    let laserFlickers = (0..<4).map { _ in CAShapeLayer() }
    let impactBurst = CAShapeLayer()

    // Monster wolf claw
    let clawGlows = (0..<3).map { _ in CAShapeLayer() }
    let clawCores = (0..<3).map { _ in CAShapeLayer() }
    let clawSparks = (0..<6).map { _ in CAShapeLayer() }
}

extension CALayer {
    /// Adds the layer to `host` the first time it is played, and does nothing on
    /// every replay after that.
    func attachIfNeeded(to host: CALayer?) {
        guard superlayer == nil, let host else {
            return
        }
        host.addSublayer(self)
    }
}
