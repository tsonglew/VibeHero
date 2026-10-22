import AppKit

// MARK: - Token polling, combat and progression
//
// The state machine that turns scanned token usage into attacks, damage, XP,
// loot and defeat/revive. Split from the view's construction and layout so the
// two can be read and changed independently; the rules it applies live in
// `Game/Rules/`.

extension NotchContentView {

    func startUsageMonitor() {
        guard usageTimer == nil else { return }
        refreshUsage()
        startFileMonitor()

        // Directory vnode notifications are not recursive. Polling is the
        // reliable path for appends in nested session directories; watchers
        // only accelerate changes they can observe.
        let refreshTimer = Timer(timeInterval: TokenActivity.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsage()
                self?.refreshSessionsIfVisible()
            }
        }
        RunLoop.main.add(refreshTimer, forMode: .common)
        usageTimer = refreshTimer

        let attackTimer = Timer(timeInterval: CombatTiming.monsterAttackInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickMonsterAttack()
            }
        }
        RunLoop.main.add(attackTimer, forMode: .common)
        monsterAttackTimer = attackTimer
    }

    /// Watches source roots for creations and replacements. Nested file appends
    /// are handled by the regular incremental poll, not directory notifications.
    func startFileMonitor() {
        for root in AgentSourceCatalog.watchRoots {
            guard FileManager.default.fileExists(atPath: root.path) else {
                continue
            }

            let fd = open(root.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .rename],
                queue: fileMonitorQueue
            )

            source.setEventHandler { [weak self] in
                DispatchQueue.main.async {
                    self?.scheduleUsageRefresh()
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            fileMonitors.append(source)
        }
    }

    func scheduleUsageRefresh() {
        usageRefreshWorkItem?.cancel()
        let refresh = DispatchWorkItem { [weak self] in
            self?.usageRefreshWorkItem = nil
            self?.refreshUsage()
        }
        usageRefreshWorkItem = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: refresh)
    }

    func tickMonsterAttack(now: Date = Date()) {
        advancePassiveRecovery(now: now)
        refreshSkillModifiers()
        advanceMonsterRecovery(now: now)
        // Earned tokens keep resolving while usage is active, in every HUD
        // mode. Enemy counterattack eligibility does not govern this ledger.
        advanceTokenCombat()
        _ = attemptAutoCast(now: now)
        updateGameLabels()
        let hasActiveTokens = tokenActivityExpiresAt.map { $0 > now } ?? false
        guard hasRealUsageData, !hasActiveTokens else {
            return
        }
        _ = maybeMonsterAttack(now: now)
        updateGameLabels()
    }

    func refreshUsage() {
        guard !usageScanInFlight else {
            return
        }
        usageScanInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = TokenUsageScanner.scanToday()
            DispatchQueue.main.async {
                self?.usageScanInFlight = false
                self?.applyUsageSnapshot(snapshot)
            }
        }
    }

    func applyUsageSnapshot(_ snapshot: TokenUsageSnapshot) {
        let now = snapshot.generatedAt
        // Settle the old activity interval before a new burst changes expiry.
        advanceMonsterRecovery(now: now)
        hasRealUsageData = snapshot.hasRealData
        todayTokens = snapshot.totalTokens
        activeSource = snapshot.dominantSource
        xpRate = snapshot.recentTokens / 10
        let tokenDelta = usageCursor.consume(total: snapshot.totalTokens, at: now)

        guard snapshot.hasRealData else {
            tokenActivityExpiresAt = nil
            setTokenActivity(false)
            applyNoDataLabels()
            updateGameLabels()
            return
        }

        if tokenDelta > 0 {
            refreshTokenActivity(now: now, didSpendTokens: true, latestEventAt: snapshot.latestEventAt)
            lastTokenSpendAt = now
            lastMonsterAttackAt = nil
            if isDefeated && !isCamping {
                reviveHeroFromTokenSpend()
            }
            tickBattle(tokenDelta: tokenDelta, now: now)
        } else {
            refreshTokenActivity(now: now, didSpendTokens: false, latestEventAt: snapshot.latestEventAt)
            if lastTokenSpendAt == nil {
                lastTokenSpendAt = snapshot.latestEventAt
            }
            updateGameLabels()
        }
    }

    func applyNoDataLabels() {
        compactLevelLabel.stringValue = L10n.string(.hudLevel, heroLevel)
        compactTokenLabel.stringValue = "—"
        tokenLabel.stringValue = L10n.string(.hudTokenTotal, "—")
        compactStatusLabel.stringValue = L10n.text(isCamping ? .campStatusShort : .hudWaiting)
        rateLabel.stringValue = L10n.string(.xpPerMinute, "0")
        combatLabel.stringValue = L10n.text(.noLocalTokenEvents)
    }

    func tickBattle(tokenDelta: Int, now: Date = Date()) {
        guard !isDefeated || isCamping else {
            combatLabel.stringValue = L10n.text(.heroDefeated)
            return
        }

        advancePassiveRecovery(now: now)
        refreshSkillModifiers()
        let modifiers = TokenCombatModifiers(
            damagePerToken: skillModifiers.damageMultiplier * selectedRole.damageMultiplier * HeroDamage.outgoingMultiplier(),
            critChance: CombatTiming.critChance + Double(skillModifiers.critChanceBonus),
            energyPerToken: SkillCharge.energyPerToken * skillModifiers.attackChargeMultiplier
                * skillModifiers.energyChargeMultiplier * ItemSystem.skillChargeMultiplier()
        )
        let recovery = tokenAccounting.deposit(tokens: tokenDelta, at: now, modifiers: modifiers)
        heroHealth = min(1, heroHealth + recovery.healingPoints / CGFloat(heroMaxHP))
        completeCampRevivalIfReady()
        gainSkillEnergy(by: recovery.energy)
        comboCount = tokenAccounting.comboCount
        if comboCount >= 2 && !isCamping {
            battleScene.playCombo(comboCount)
        }
        combatLabel.stringValue = L10n.string(.sourceUsageTokens, activeSource, formatTokens(tokenDelta))

        advanceTokenCombat()
        // Auto-casting runs on the fixed logical timer, never once per scan.
        updateGameLabels()
    }

    func advanceTokenCombat() {
        guard !isCamping else { return }
        flushPendingHeroStrikes()
        // Keep large waiting budgets compressed while walking or respawning.
        guard !isDefeated, battleScene.monsterEngaged, monsterHealth > 0, damageBank.isEmpty else { return }
        for strike in tokenAccounting.resolveNext() {
            damageBank.deposit(strike)
        }
        flushPendingHeroStrikes()
    }

    func enqueueHeroStrike(_ strike: ResolvedHeroStrike) {
        damageBank.deposit(strike)
        flushPendingHeroStrikes()
    }

    func flushPendingHeroStrikes() {
        while !isCamping, !isDefeated, battleScene.monsterEngaged, monsterHealth > 0 {
            let maxHP = CGFloat(StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss))
            let capacity = monsterMechanics.damageCapacity(remainingHP: monsterHealth * maxHP)
            guard let strike = damageBank.consume(upTo: capacity) else { break }
            applyHeroStrikeImpact(strike)
        }
    }

    func applyHeroStrikeImpact(_ strike: ResolvedHeroStrike) {
        guard !isCamping, !isDefeated, monsterHealth > 0 else {
            return
        }
        // Start presentation before a fatal hit hides the target. The queue is
        // visual only: dropping it or changing HUD mode cannot drop damage.
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let shieldLost = min(monsterMechanics.shieldPoints, strike.damagePoints)
        let hpDamage = max(0, strike.damagePoints - shieldLost)
        if hpDamage > 0 {
            let displayedDamage = NSNumber(value: Double(max(1, hpDamage.rounded())))
            let damageText = formatter.string(from: displayedDamage) ?? displayedDamage.stringValue
            battleScene.playAttack(damageText: damageText, isCrit: strike.isCrit)
        } else if let monster = battleScene.currentMonster {
            battleScene.enqueueHeroAttack(HeroAttackRequest(monsterID: monster.id, damageText: nil, isCrit: strike.isCrit))
        }
        if shieldLost > 0 {
            battleScene.showFloatingText(L10n.string(.shieldAbsorbed, Double(shieldLost)), color: .systemCyan, anchor: .monster)
        }
        if let reward = damageMonster(by: strike.damagePoints) {
            combatLabel.stringValue = defeatText(for: reward)
        }
        playCompactHeroAttack()
        updateGameLabels()
    }

    @discardableResult
    func damageMonster(by damagePoints: CGFloat) -> DefeatReward? {
        guard !isCamping, !isDefeated, monsterHealth > 0, damagePoints.isFinite, damagePoints > 0 else {
            return nil
        }

        monsterRespawnWorkItem?.cancel()
        let maxHP = CGFloat(StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss))
        let application = monsterMechanics.applyDamage(damagePoints, remainingHP: monsterHealth * maxHP, maximumHP: maxHP)
        monsterHealth = max(0, monsterHealth * maxHP - application.hpLost) / maxHP
        battleScene.monsterHealth = monsterHealth

        guard monsterHealth <= 0 else {
            return nil
        }

        let wasBoss = currentMonsterIsBoss
        let killStage = currentStage
        totalKills += 1
        StageTracker.saveTotalKills(totalKills)
        var reward = grantExperience(for: currentMonster, isBoss: wasBoss, stage: killStage)
        if wasBoss {
            let bossGold = ItemSystem.addGold(Int.random(in: 20...40), multiplier: skillModifiers.goldMultiplier, kind: .bossGold)
            reward.bossGold = bossGold
        }
        battleScene.playMonsterDeath()
        reward.loot = awardLoot(isBoss: wasBoss)
        if reward.didLevelUp {
            battleScene.playLevelUp()
        }
        let nextStage = StageProgress.stage(for: totalKills)
        if nextStage > killStage {
            battleScene.playStageBanner(
                L10n.string(.stageReached, nextStage),
                isBoss: StageProgress.isBossEncounter(totalKills: totalKills)
            )
        }
        scheduleMonsterRespawn()
        updateTitleLabel()
        return reward
    }

    // Spawn a new batch without crossing a stage boundary. A boss stage starts
    // with one boss encounter; the rest of that stage returns to regular waves.
    func spawnNextMonsterBatch() {
        let plan = MonsterEncounterPlanner.makeBatch(
            totalKills: totalKills,
            startingKind: nextMonsterKind,
            requestedCount: Int.random(in: 5...8)
        )
        guard let firstEncounter = plan.encounters.first else { return }

        nextMonsterKind = plan.nextKind
        battleScene.spawnMonsterBatch(plan.encounters)
        activateMonster(firstEncounter, announce: true)
    }

    func activateMonster(_ encounter: MonsterEncounter, announce: Bool) {
        currentMonster = encounter.kind
        currentMonsterStage = encounter.stage
        currentMonsterIsBoss = encounter.isBoss
        monsterMechanics = MonsterMechanicsState(encounter: encounter)
        lastMonsterRecoveryAt = Date()
        monsterHealth = 1

        monsterHPLabel.textColor = .white.withAlphaComponent(0.78)
        monsterHPBar.fillColor = currentMonster.hpColor
        compactHeroView.monsterKind = currentMonster
        compactHeroView.isBoss = currentMonsterIsBoss

        if announce, currentMonsterIsBoss {
            combatLabel.stringValue = L10n.string(.bossAppears, currentMonster.displayName)
            battleScene.playStageBanner(L10n.string(.bossAppears, currentMonster.shortName), isBoss: true)
        } else if announce, hasRealUsageData, lootMessageExpiresAt.map({ $0 <= Date() }) != false {
            combatLabel.stringValue = L10n.string(.monsterRespawned, currentMonster.displayName)
        }
        updateTitleLabel()
        updateGameLabels()
        // The scene must not announce engagement before this encounter's
        // metadata and HP are installed in the combat controller.
        battleScene.updateWorld(dt: 0)
    }

    // Called when a single monster in the batch is defeated
    func scheduleMonsterRespawn() {
        guard !isCamping else { return }
        monsterRespawnWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.advanceMonsterAfterDefeat()
        }
        monsterRespawnWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: workItem)
    }

    func advanceMonsterAfterDefeat() {
        guard !isCamping, monsterHealth <= 0 else { return }
        monsterRespawnWorkItem?.cancel()
        monsterRespawnWorkItem = nil
        if let nextEncounter = battleScene.advanceToNextMonster() {
            activateMonster(nextEncounter, announce: true)
        } else {
            spawnNextMonsterBatch()
        }
    }

    func maybeMonsterAttack(now: Date) -> Bool {
        guard !isCamping else { return false }
        guard !isDefeated else {
            combatLabel.stringValue = L10n.text(.heroDefeated)
            return true
        }
        guard monsterHealth > 0 else {
            return false
        }
        guard battleScene.monsterEngaged else {
            return false
        }

        if let lastMonsterAttackAt,
           now.timeIntervalSince(lastMonsterAttackAt) < CombatTiming.idleAttackCooldown {
            combatLabel.stringValue = L10n.string(.monsterAttackingNoTokens, currentMonster.shortName)
            return true
        }

        lastMonsterAttackAt = now
        comboCount = 0
        tokenAccounting.breakCombo()
        let baseDamageFraction = CombatTiming.monsterDamagePerHit
            * selectedRole.idleDamageMultiplier
            * ItemSystem.idleDamageTakenMultiplier()
        let damagePoints = CombatTiming.monsterDamagePoints(for: baseDamageFraction)
            * (1 - skillModifiers.damageReduction) * monsterMechanics.attackMultiplier
        battleScene.playMonsterAttack(damage: damagePoints)
        applyMonsterStrikeImpact(damagePoints: damagePoints)
        return true
    }

    func applyMonsterStrikeImpact(damagePoints: CGFloat) {
        guard !isCamping, !isDefeated else {
            return
        }
        heroHealth = max(0, heroHealth - damagePoints / CGFloat(heroMaxHP))
        combatLabel.stringValue = L10n.string(.monsterAttackingNoTokens, currentMonster.shortName)
        playCompactMonsterAttack()
        if heroHealth <= 0 {
            enterDefeatedState()
        }
        updateGameLabels()
    }

    func updateGameLabels() {
        compactLevelLabel.stringValue = L10n.string(.hudLevel, heroLevel)
        compactTokenLabel.stringValue = hasRealUsageData ? formatTokens(todayTokens) : "—"
        tokenLabel.stringValue = L10n.string(.hudTokenTotal, hasRealUsageData ? formatTokens(todayTokens) : "—")
        goldLabel.stringValue = L10n.string(.hudGoldTotal, formatTokens(ItemSystem.gold))
        let boostRemaining = ItemSystem.powerBoostRemaining()
        rateLabel.stringValue = boostRemaining > 0
            ? L10n.string(.tokenRateBuff, formatTokens(xpRate), boostRemaining)
            : L10n.string(.xpPerMinute, formatTokens(xpRate))
        let preciseTokens = hasRealUsageData ? todayTokens.formatted() : L10n.text(.noLocalUsage)
        let tokenDetail = L10n.string(.hudTokenDetails, preciseTokens, xpRate.formatted())
        tokenLabel.toolTip = tokenDetail
        tokenLabel.setAccessibilityLabel(tokenDetail)
        compactTokenLabel.toolTip = tokenDetail
        compactTokenLabel.setAccessibilityLabel(tokenDetail)
        goldLabel.toolTip = L10n.string(.hudGoldTotal, ItemSystem.gold.formatted())
        goldLabel.setAccessibilityLabel(goldLabel.toolTip)
        updateCompactStatus()
        updateTitleLabel()
        updateSkillUI()
        updateStatLabels()
        compactHPBar.value = heroHealth
        compactXPBar.value = xpProgress
        heroHPBar.value = heroHealth
        heroXPBar.value = xpProgress
        monsterHPBar.value = monsterHealth
        battleScene.monsterHealth = monsterHealth
        let lowHPWarning = heroHealth <= 0.3 && !isDefeated
        heroHPBar.isWarning = lowHPWarning
        compactHPBar.isWarning = lowHPWarning
        updateDefeatPresentation()
        combatLabel.toolTip = combatLabel.stringValue
        skillEnergyLabel.toolTip = skillEnergyLabel.stringValue
        skillEnergyBar.toolTip = skillEnergyLabel.stringValue
        skillEnergyBar.setAccessibilityLabel(skillEnergyLabel.stringValue)
        skillEnergyBar.setAccessibilityValue(Double(skillEnergyBar.value))
        refreshEncounterPresentation(now: Date())
    }

    func updateCompactStatus() {
        let key: L10nKey = isCamping ? .campStatusShort : isDefeated ? .hudDefeated
            : !hasRealUsageData ? .hudWaiting
            : (tokenActivityExpiresAt.map { $0 > Date() } ?? false) ? .hudActive : .hudIdle
        compactStatusLabel.stringValue = L10n.text(key)
        compactHeroView.setAccessibilityLabel(L10n.string(.hudHeroStatus, selectedRole.label, compactStatusLabel.stringValue))
    }

    func refreshTokenActivity(now: Date, didSpendTokens: Bool, latestEventAt: Date?) {
        advanceMonsterRecovery(now: now)
        let expiration = TokenActivity.expiration(
            now: now, previous: tokenActivityExpiresAt,
            didSpendTokens: didSpendTokens, latestEventAt: latestEventAt
        )
        if let expiration, expiration != tokenActivityExpiresAt {
            scheduleTokenActivityExpiration(at: expiration)
        }
        tokenActivityExpiresAt = expiration
        setTokenActivity(expiration != nil)
    }

    func scheduleTokenActivityExpiration(at expiration: Date) {
        tokenActivityExpirationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.expireTokenActivity(now: Date())
        }
        tokenActivityExpirationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, expiration.timeIntervalSinceNow),
            execute: workItem
        )
    }

    func expireTokenActivity(now: Date) {
        guard let expiration = tokenActivityExpiresAt, expiration <= now else { return }
        // Preserve the old expiry while settling this interval. Clearing it
        // first would classify the entire last logical tick as idle.
        advanceMonsterRecovery(now: now)
        tokenActivityExpiresAt = nil
        tokenActivityExpirationWorkItem = nil
        setTokenActivity(false)
    }

    func playCompactMonsterAttack() {
        guard presentationPolicy.animatesCompact else {
            return
        }

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -3, 2, -1, 0]
        shake.duration = 0.24
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(shake, forKey: "compactMonsterHit")

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1.0, 0.42, 1.0]
        flash.duration = 0.24
        compactHPBar.layer?.add(flash, forKey: "compactMonsterHitFlash")
    }

    // Collapsed-mode feedback for hero strikes: a tiny forward jab plus a
    // pulse on the XP bar, so attacks are visible without expanding.
    func playCompactHeroAttack() {
        guard presentationPolicy.animatesCompact else {
            return
        }

        let jab = CAKeyframeAnimation(keyPath: "transform.translation.x")
        jab.values = [0, 2.5, -1, 0]
        jab.duration = 0.2
        jab.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(jab, forKey: "compactHeroJab")

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1.0, 0.35, 1.0]
        flash.duration = 0.22
        compactXPBar.layer?.add(flash, forKey: "compactHeroAttackFlash")
    }

    func setTokenActivity(_ active: Bool) {
        if !active {
            if tokenActivityExpiresAt != nil { advanceMonsterRecovery(now: Date()) }
            tokenActivityExpiresAt = nil
            tokenActivityExpirationWorkItem?.cancel()
            tokenActivityExpirationWorkItem = nil
        }
        let effectiveActive = active && !isDefeated
        compactHeroView.setTokenActivity(effectiveActive)
        battleScene.tokenActivity = effectiveActive
        updateCompactStatus()
    }

    var heroMaxHP: Int { GameStats.maximumHeroHP(multiplier: skillModifiers.maxHPMultiplier) }

    func refreshSkillModifiers() {
        skillModifiers = SkillTreeProgress.modifiers()
    }

    /// Regeneration uses elapsed time and the previously active build. Polling
    /// more often cannot create more healing, nor can death passively revive.
    func advancePassiveRecovery(now: Date) {
        let elapsed = now.timeIntervalSince(lastPassiveRecoveryAt)
        guard elapsed.isFinite, elapsed > 0 else { return }
        lastPassiveRecoveryAt = now
        if isCamping {
            heroHealth = min(1, heroHealth + CGFloat(elapsed) * CampRecovery.pointsPerSecond / CGFloat(heroMaxHP))
            completeCampRevivalIfReady()
        } else if !isDefeated {
            heroHealth = min(1, heroHealth + CGFloat(elapsed) * skillModifiers.hpRegenPointsPerSecond / CGFloat(heroMaxHP))
        }
    }

    func initializeCampState() {
        battleScene.combatPaused = isCamping
        applyPresentationPolicy()
    }

    @objc func toggleCamp() { setCamping(!isCamping) }

    func setCamping(_ camping: Bool, now: Date = Date()) {
        guard camping != isCamping else { return }
        // Attribute elapsed time to the state that was actually active.
        advancePassiveRecovery(now: now)
        advanceMonsterRecovery(now: now)
        isCamping = camping
        CampProgress.save(camping)
        lastPassiveRecoveryAt = now
        lastMonsterRecoveryAt = now
        battleScene.combatPaused = camping
        applyPresentationPolicy()
        if camping {
            monsterRespawnWorkItem?.cancel()
            monsterRespawnWorkItem = nil
        } else {
            lastMonsterAttackAt = now
            if monsterHealth <= 0 {
                scheduleMonsterRespawn()
            } else {
                advanceTokenCombat()
            }
        }
        updateGameLabels()
    }

    func completeCampRevivalIfReady() {
        guard isCamping, isDefeated, heroHealth >= CombatTiming.reviveHealth else { return }
        isDefeated = false
        comboCount = 0
        tokenAccounting.breakCombo()
        updateDefeatPresentation()
        setTokenActivity(tokenActivityExpiresAt.map { $0 > Date() } ?? false)
        playReviveEffects(restoredHP: statValue(heroHealth, maxValue: heroMaxHP))
    }

    func handleMonsterEngaged(now: Date = Date()) {
        lastMonsterRecoveryAt = now
        advanceTokenCombat()
    }

    func advanceMonsterRecovery(now: Date) {
        let previous = lastMonsterRecoveryAt
        guard now > previous else { return }
        lastMonsterRecoveryAt = now
        guard !isCamping, !isDefeated, monsterHealth > 0, battleScene.monsterEngaged else { return }
        // Only the idle portion of this interval counts. Camp and death update
        // the clock above, so returning never restores missed regeneration.
        let idleFrom = max(previous, tokenActivityExpiresAt ?? previous)
        guard now > idleFrom else { return }
        let maxHP = CGFloat(StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss))
        let healed = monsterMechanics.recoveredHP(elapsed: now.timeIntervalSince(idleFrom),
                                                  currentHP: monsterHealth * maxHP, maximumHP: maxHP)
        monsterHealth = min(1, monsterHealth + healed / maxHP)
        battleScene.monsterHealth = monsterHealth
    }

    func encounterPresentation(now: Date = Date()) -> MonsterEncounterPresentation {
        MonsterEncounterPresentation(
            shieldRemaining: monsterMechanics.shieldPoints,
            shieldMaximum: monsterMechanics.maxShieldPoints,
            idleRegenerationActive: !isCamping && !isDefeated && monsterHealth > 0
                && battleScene.monsterEngaged && !(tokenActivityExpiresAt.map { $0 > now } ?? false),
            idleRegenerationFractionPerSecond: monsterMechanics.idleRecoveryFractionPerSecond,
            bossPhase: currentMonsterIsBoss ? (monsterMechanics.isEnraged ? 2 : 1) : nil
        )
    }

    func readyAutoCastSkill(now: Date, loadout: SkillLoadout) -> HeroSkill? {
        SkillProgress.autoCastCandidates(loadout: loadout)
            .filter { (skillCooldowns[$0] ?? .distantPast) <= now }
            .sorted {
                if $0.treeTier != $1.treeTier { return $0.treeTier > $1.treeTier }
                return $0.castEnergyRequirement > $1.castEnergyRequirement
            }.first
    }

    @discardableResult
    func attemptAutoCast(now: Date) -> HeroSkill? {
        guard !isCamping, !isDefeated, battleScene.monsterEngaged, monsterHealth > 0 else { return nil }
        let loadout = SkillProgress.loadout()
        guard let skill = readyAutoCastSkill(now: now, loadout: loadout),
              skillEnergy >= CGFloat(skill.castEnergyRequirement) else { return nil }
        let damage = SkillCombat.damage(for: skill, rank: loadout.rank(for: skill), modifiers: skillModifiers,
                                        outgoingMultiplier: selectedRole.damageMultiplier * HeroDamage.outgoingMultiplier())
        guard damage.isFinite, damage > 0 else { return nil }

        // Charge and cooldown commit only when a live target can receive the
        // cast. Its damage enters the same synchronous bank as basic attacks.
        skillEnergy -= CGFloat(skill.castEnergyRequirement)
        skillCooldowns[skill] = now.addingTimeInterval(skill.castCooldown * Double(skillModifiers.cooldownMultiplier))
        combatLabel.stringValue = L10n.string(.skillCasting, skill.name)
        battleScene.showFloatingText(skill.name, color: .systemCyan, fontSize: 11, anchor: .center)
        enqueueHeroStrike(ResolvedHeroStrike(damagePoints: damage, isCrit: false))
        return skill
    }

    func updateSkillUI() {
        let loadout = SkillProgress.loadout()
        let points = SkillProgress.availablePoints(heroLevel: heroLevel)
        skillLabel.stringValue = points == 1 ? L10n.text(.skillPointShort) : L10n.string(.skillPointsShort, points)
        skillEnergyBar.value = skillEnergy / SkillCharge.maximumEnergy
        if isCamping {
            skillEnergyLabel.stringValue = L10n.string(.campPausedSkill, formatTokens(Int(skillEnergy)),
                                                      formatTokens(Int(SkillCharge.maximumEnergy)))
            return
        }

        guard !isDefeated else {
            skillEnergyLabel.stringValue = L10n.text(.heroDefeated)
            return
        }

        let unlockedSkillCount = HeroSkill.allCases.filter { loadout.rank(for: $0) > 0 }.count
        let castCandidates = SkillProgress.autoCastCandidates(loadout: loadout)
        guard !castCandidates.isEmpty else {
            skillEnergyLabel.stringValue = unlockedSkillCount == 0 ? L10n.text(.noSkillEquipped) : L10n.text(.noSkillEnabled)
            return
        }

        let now = Date()
        guard let skill = readyAutoCastSkill(now: now, loadout: loadout) else {
            let nextReady = castCandidates.compactMap { skillCooldowns[$0] }.min() ?? now
            skillEnergyLabel.stringValue = L10n.string(.skillCooldownStatus, max(0, Int(ceil(nextReady.timeIntervalSince(now)))))
            return
        }
        if skillEnergy >= CGFloat(skill.castEnergyRequirement) {
            skillEnergyLabel.stringValue = L10n.string(.skillReadyStatus, skill.name)
        } else {
            skillEnergyLabel.stringValue = L10n.string(.skillEnergyStatus, formatTokens(Int(skillEnergy)), formatTokens(skill.castEnergyRequirement), skill.name)
        }
    }

    func gainSkillEnergy(by amount: CGFloat) {
        guard !isDefeated || isCamping else {
            return
        }

        let loadout = SkillProgress.loadout()
        guard loadout.totalRanks > 0 else {
            return
        }

        guard amount.isFinite, amount > 0 else { return }
        skillEnergy = min(SkillCharge.maximumEnergy, skillEnergy + amount)
    }

    func applyExperienceState(saveLevel: Bool) {
        let state = ExperienceCurve.state(for: heroExperience)
        heroLevel = state.level
        currentXP = state.currentXP
        requiredXP = state.requiredXP
        xpProgress = state.progress
        if saveLevel {
            SkillProgress.saveHeroLevel(heroLevel)
        }
    }

    func grantExperience(for monster: MonsterKind, isBoss: Bool, stage: Int) -> DefeatReward {
        let previousLevel = heroLevel
        let rewardXP = max(1, Int((CGFloat(monster.xpReward) * StageProgress.xpMultiplier(stage: stage, isBoss: isBoss) * skillModifiers.xpMultiplier).rounded()))
        heroExperience += rewardXP
        HeroExperience.saveTotalXP(heroExperience)
        applyExperienceState(saveLevel: true)
        return DefeatReward(
            monsterName: monster.displayName,
            xpGained: rewardXP,
            didLevelUp: heroLevel > previousLevel,
            level: heroLevel,
            loot: nil
        )
    }

    func defeatText(for reward: DefeatReward) -> String {
        var summaryParts: [String] = []
        if let loot = reward.loot {
            summaryParts.append(lootSummary(for: loot))
        }
        if reward.bossGold > 0 {
            summaryParts.append(L10n.string(.lootGoldSummary, reward.bossGold))
        }
        if !summaryParts.isEmpty {
            lootMessageExpiresAt = Date().addingTimeInterval(4)
            return L10n.string(.defeatedMonsterXPAndLoot, reward.monsterName, reward.xpGained, summaryParts.joined(separator: " · "))
        }
        if reward.didLevelUp {
            return L10n.string(.levelUpFromMonsterXP, reward.monsterName, reward.xpGained, reward.level)
        }
        return L10n.string(.defeatedMonsterXP, reward.monsterName, reward.xpGained)
    }

    func awardLoot(isBoss: Bool) -> LootDrop? {
        guard let drop = ItemSystem.rollDrop(isBoss: isBoss, emptyDropRescueChance: skillModifiers.emptyDropRescueChance) else {
            return nil
        }
        return applyLoot(drop)
    }

    func applyLoot(_ drop: LootDrop) -> LootDrop? {
        let awardedDrop: LootDrop
        switch drop.kind {
        case .healthPotion:
            let missingHP = max(0, Double(1 - heroHealth) * Double(heroMaxHP))
            let healedHP = min(Double(max(0, drop.amount)), missingHP)
            heroHealth = min(1, heroHealth + CGFloat(healedHP) / CGFloat(heroMaxHP))
            ItemSystem.recordHealing(healedHP)
            awardedDrop = LootDrop(kind: .healthPotion, amount: Int(healedHP), actualHealedHP: healedHP)
        case .powerBoost:
            let seconds = ItemSystem.activatePowerBoost()
            awardedDrop = LootDrop(kind: .powerBoost, amount: seconds)
        case .gold:
            let gold = ItemSystem.addGold(drop.amount, multiplier: skillModifiers.goldMultiplier)
            awardedDrop = LootDrop(kind: .gold, amount: gold)
        case .equipment:
            guard let equipment = drop.equipment else {
                return nil
            }
            let outcome = ItemSystem.awardEquipment(equipment, goldMultiplier: skillModifiers.goldMultiplier)
            switch outcome {
            case .equipped(let awarded):
                battleScene.showFloatingText(
                    awarded.summary,
                    color: awarded.rarity.color,
                    fontSize: 10,
                    anchor: .center
                )
            case .salvaged(let awarded, let gold):
                battleScene.showFloatingText(
                    L10n.string(.equipmentSalvaged, awarded.displayName, gold),
                    color: awarded.rarity.color,
                    fontSize: 10,
                    anchor: .center
                )
            }
            awardedDrop = LootDrop(kind: .equipment, amount: equipment.bonusPercent,
                                   equipment: equipment, equipmentOutcome: outcome)
        }

        battleScene.playLootDrop(awardedDrop)
        return awardedDrop
    }

    func lootSummary(for drop: LootDrop) -> String {
        switch drop.kind {
        case .healthPotion:
            L10n.string(.lootPotionExactSummary,
                        (drop.actualHealedHP ?? Double(drop.amount)).formatted(.number.precision(.fractionLength(0...1))))
        case .powerBoost:
            L10n.string(.lootBuffSummary, drop.kind.name, drop.amount)
        case .gold:
            L10n.string(.lootGoldSummary, drop.amount)
        case .equipment:
            if case .salvaged(let equipment, let gold) = drop.equipmentOutcome {
                L10n.string(.equipmentSalvaged, equipment.displayName, gold)
            } else {
                drop.equipment?.summary ?? drop.kind.name
            }
        }
    }

    func updateStatLabels() {
        let hpPercent = percentValue(heroHealth)
        let xpPercent = percentValue(xpProgress)
        let heroHP = preciseStatValue(heroHealth, maxValue: heroMaxHP)
        let heroHPText = formatHealth(heroHP)
        let monsterMaxHP = StageProgress.maxHP(stage: currentStage, monster: currentMonster, isBoss: currentMonsterIsBoss)
        let monsterHP = statValue(monsterHealth, maxValue: monsterMaxHP)
        compactHPLabel.stringValue = heroHPText
        compactXPLabel.stringValue = formatCompact(currentXP)
        heroHPLabel.stringValue = L10n.string(.hudHeroHealth, heroHPText, formatTokens(heroMaxHP))
        heroXPLabel.stringValue = L10n.string(.xpPercent, formatCompact(currentXP), formatCompact(requiredXP), xpPercent)
        let monsterName = currentMonsterIsBoss
            ? L10n.string(.bossMonsterName, currentMonster.shortName)
            : currentMonster.shortName
        monsterHPLabel.stringValue = L10n.string(.hudMonsterHealth, monsterName, formatTokens(monsterHP), formatTokens(monsterMaxHP))
        let exactHP = L10n.string(.hpPercent, heroHPText, heroMaxHP, hpPercent)
        let exactMonster = L10n.string(.monsterHP, monsterName, formatCompact(monsterHP), formatCompact(monsterMaxHP), percentValue(monsterHealth))
        for bar in [compactHPBar, heroHPBar] {
            bar.toolTip = exactHP
            bar.setAccessibilityLabel(exactHP)
            bar.setAccessibilityValue(Double(heroHealth))
        }
        heroHPLabel.toolTip = exactHP
        monsterHPLabel.toolTip = exactMonster
        monsterHPBar.toolTip = exactMonster
        monsterHPBar.setAccessibilityLabel(exactMonster)
        monsterHPBar.setAccessibilityValue(Double(monsterHealth))
        heroXPBar.toolTip = heroXPLabel.stringValue
        heroXPBar.setAccessibilityLabel(heroXPLabel.stringValue)
        heroXPBar.setAccessibilityValue(Double(xpProgress))
    }

    func enterDefeatedState() {
        guard !isDefeated else {
            return
        }

        isDefeated = true
        heroHealth = 0
        setTokenActivity(false)
        combatLabel.stringValue = L10n.text(.heroDefeated)
        updateDefeatPresentation()
        updateGameLabels()
    }

    func reviveHeroFromTokenSpend() {
        refreshSkillModifiers()
        isDefeated = false
        heroHealth = CombatTiming.reviveHealth
        lastMonsterAttackAt = nil
        comboCount = 0
        tokenAccounting.breakCombo()
        combatLabel.stringValue = L10n.text(.heroReviving)
        updateDefeatPresentation()
        lastPassiveRecoveryAt = Date()
        lastMonsterRecoveryAt = lastPassiveRecoveryAt
        playReviveEffects(restoredHP: statValue(CombatTiming.reviveHealth, maxValue: heroMaxHP))
        setTokenActivity(tokenActivityExpiresAt.map { $0 > Date() } ?? false)
        flushPendingHeroStrikes()
    }

    func playReviveEffects(restoredHP: Int) {
        battleScene.playHeroReviveHeal(restoredHP: restoredHP)
        guard presentationPolicy.animatesCompact else { return }

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [0.82, 1.22, 1.0]
        pulse.keyTimes = [0, 0.48, 1]
        pulse.duration = 0.42
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHeroView.layer?.add(pulse, forKey: "compactHeroRevivePulse")

        let glow = CAKeyframeAnimation(keyPath: "opacity")
        glow.values = [0.45, 1.0, 0.72]
        glow.keyTimes = [0, 0.44, 1]
        glow.duration = 0.42
        glow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        compactHPBar.layer?.add(glow, forKey: "compactHPReviveGlow")
    }

    func updateDefeatPresentation() {
        compactHeroView.monsterKind = currentMonster
        compactHeroView.isBoss = currentMonsterIsBoss
        if isDefeated {
            compactHeroView.kind = .monster
            compactHeroView.setTokenActivity(false)
            compactHeroView.setWalking(false)
        } else {
            compactHeroView.kind = .hero
            compactHeroView.setWalking(!isExpanded && battleScene.worldIsMoving)
        }
        battleScene.heroDefeated = isDefeated
    }

    func percentValue(_ value: CGFloat) -> Int {
        min(100, max(0, Int(round(value * 100))))
    }

    func statValue(_ value: CGFloat, maxValue: Int) -> Int {
        min(maxValue, max(0, Int(round(value * CGFloat(maxValue)))))
    }

    func preciseStatValue(_ value: CGFloat, maxValue: Int) -> CGFloat {
        min(CGFloat(maxValue), max(0, value * CGFloat(maxValue)))
    }

    func formatHealth(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    // Keep resource columns bounded; exact values remain in their tooltips.
    func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000_000_000_000 { return String(format: "%.1e", Double(value)) }
        for (threshold, suffix) in [(1_000_000_000_000, "T"), (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")] {
            if value >= threshold { return String(format: "%.1f%@", Double(value) / Double(threshold), suffix) }
        }
        return "\(value)"
    }

    // Game values (HP, damage, XP): full number
    func formatCompact(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
