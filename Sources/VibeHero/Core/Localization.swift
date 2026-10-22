import Foundation

extension Notification.Name {
    static let notchHeroLanguageChanged = Notification.Name(DefaultsKey.prefix + "languageChanged")
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"


    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .japanese: "日本語"
        }
    }

    static func load() -> AppLanguage {
        if let rawValue = Defaults.string(forKey: DefaultsKey.language),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }

        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }
        return .english
    }

    static func save(_ language: AppLanguage) {
        Defaults.set(language.rawValue, forKey: DefaultsKey.language)
        NotificationCenter.default.post(name: .notchHeroLanguageChanged, object: language)
    }
}

enum L10nKey: String, CaseIterable {
    case openVibeHero
    case openSettings
    case quitVibeHero
    case settingsTitle
    case language
    case heroRole
    case display
    case skills
    case inDevelopment
    case inDevelopmentSkillsDetail
    case inDevelopmentEquipmentDetail
    case tokenHooks
    case tokenHooksDetail
    case installHook
    case hookInstalled
    case hookInstallFailed
    case hookInstalledDetail
    case hookClaudeDetail
    case hookCodexDetail
    case hookOpenCodeDetail
    case hookOpenClawDetail
    case hookHermesDetail
    case hookKimiDetail
    case nativeAutomatic
    case nativeWaiting
    case nativeWaitingDetail
    case nativeReceiving
    case followActiveDisplay
    case fixedToDisplay
    case followsActiveDisplay
    case pinnedDisplayMissing
    case fullScreen
    case hideInFullScreen
    case hideInFullScreenDetail
    case skillPointsAvailable
    case oneSkillPointAvailable
    case skillPointShort
    case skillPointsShort
    case skillEnergyPercent
    case skillReadyStatus
    case skillCooldownStatus
    case noSkillEquipped
    case noSkillEnabled
    case autoCast
    case locked
    case unlock
    case upgrade
    case maxed
    case requiresButton
    case rank
    case tier
    case requiresPrefix
    case effectPrefix
    case unlocksAtLevel
    case requiresSkillRank
    case appTitleWithRole
    case todayTokens
    case xpPerMinute
    case noData
    case noLocalUsage
    case waiting
    case noLocalTokenEvents
    case tokenStreamStatus
    case watchingSourceLogs
    case defeatedMonster
    case sourceUsageTokens
    case skillCasting
    case skillCastDefeated
    case defeatedMonsterXP
    case levelUpFromMonsterXP
    case levelUpSkillPoint
    case sustainedDefeatedMonster
    case monsterRespawned
    case noRecentTokenSpend
    case idleTooLong
    case idleCounterattacks
    case monsterAttackingNoTokens
    case heroDefeated
    case heroReviving
    case monsterHP
    case hpPercent
    case xpPercent
    case hpDamage
    case hpDamageDecimal
    case hpHeal
    case todayTokensGold
    case tokenRateBuff
    case lootHealthPotion
    case lootPowerBoost
    case lootGold
    case lootPotionSummary
    case lootBuffSummary
    case lootGoldSummary
    case defeatedMonsterXPAndLoot

    case rolePMLabel
    case roleDesignerLabel
    case roleArtistLabel
    case roleEngineerLabel
    case roleQALabel
    case roleOtherLabel
    case rolePMDetail
    case roleDesignerDetail
    case roleArtistDetail
    case roleEngineerDetail
    case roleQADetail
    case roleOtherDetail
    case rolePMPerk
    case roleDesignerPerk
    case roleArtistPerk
    case roleEngineerPerk
    case roleQAPerk
    case roleOtherPerk

    case skillPulseBladeName
    case skillTokenVolleyName
    case skillArcBurstName
    case skillWraithMarkName
    case skillNovaStormName
    case skillOverclockCoreName
    case skillPulseBladeSummary
    case skillTokenVolleySummary
    case skillArcBurstSummary
    case skillWraithMarkSummary
    case skillNovaStormSummary
    case skillOverclockCoreSummary
    case skillPulseBladeEffect
    case skillTokenVolleyEffect
    case skillArcBurstEffect
    case skillWraithMarkEffect
    case skillNovaStormEffect
    case skillOverclockCoreEffect

    case monsterPromptWraith
    case monsterCacheGolem
    case monsterTokenSlime
    case monsterNullSentinel
    case monsterPromptWraithShort
    case monsterCacheGolemShort
    case monsterTokenSlimeShort
    case monsterNullSentinelShort

    case lootEquipment
    case rarityCommon
    case rarityUncommon
    case rarityRare
    case rarityEpic
    case rarityLegendary
    case slotWeapon
    case slotArmor
    case slotCharm
    case equipmentName
    case equipmentBonusWeapon
    case equipmentBonusArmor
    case equipmentBonusCharm
    case lootEquipmentSummary
    case equipmentEquipped
    case equipmentSalvaged
    case equipmentSectionTitle
    case hudLevel
    case hudLevelStage
    case hudTokenTotal
    case hudGoldTotal
    case hudTokenDetails
    case hudActive
    case hudIdle
    case hudWaiting
    case hudDefeated
    case hudHeroStatus
    case hudHeroHealth
    case hudMonsterHealth
    case campEnter
    case campLeave
    case campStatusShort
    case campResting
    case campRecovering
    case campPausedSkill
    case campRules
    case monsterShieldStatus
    case monsterShieldDetails
    case monsterRegenerationStatus
    case monsterRegenerationPausedStatus
    case monsterRegenerationDetails
    case bossPhase1Status
    case bossPhase2Status
    case bossPhaseDetails
    case shieldAbsorbed
    case roleStatsShort
    case roleChoiceAccessibility
    case equipmentGoldBalance
    case equipmentBoostActive
    case equipmentBoostInactive
    case equipmentRules
    case equipmentRecentRewards
    case equipmentHistoryEmpty
    case equipmentCurrentState
    case equipmentNextState
    case equipmentSlotEmpty
    case equipmentEmptyReason
    case equipmentMaxedReason
    case equipmentInsufficientGold
    case equipmentUpgradeAction
    case equipmentUpgradePrice
    case equipmentUpgradeAccessibility
    case equipmentUnavailableAccessibility
    case equipmentDetailedWeapon
    case equipmentDetailedArmor
    case equipmentDetailedCharm
    case equipmentHistoryPotion
    case equipmentHistoryBoost
    case equipmentHistoryGold
    case equipmentHistoryBossGold
    case equipmentHistoryUpgrade
    case lootPotionExactSummary
    case lootPotionExactFloat
    case stageTag
    case stageTagBoss
    case stageReached
    case bossAppears
    case bossMonsterName
    case comboText
    case critLabel
    case levelUpBanner

    case backdrop
    case backdropMidnightForest
    case backdropCrystalCave
    case backdropSunsetDunes
    case backdropNeonCity

    // MARK: - Skill Tree
    case skillTreeAttack
    case skillTreeDefense
    case skillTreeEconomy
    case skillTreeAbility
    case availableSkillPoints
    case selectNodePrompt
    case currentLevel
    case requiresHeroLevel
    case requiresParent
    case nodeUpgrade
    case nodeDowngrade
    case nodeMaxed

    // Attack nodes
    case nodeAttackPower1
    case nodeAttackPower1Desc
    case nodeAttackPower2
    case nodeAttackPower2Desc
    case nodeCritChance1
    case nodeCritChance1Desc
    case nodeAttackSpeed1
    case nodeAttackSpeed1Desc
    case nodeAttackMastery
    case nodeAttackMasteryDesc
    case nodeBerserk
    case nodeBerserkDesc

    // Defense nodes
    case nodeHPBonus1
    case nodeHPBonus1Desc
    case nodeHPBonus2
    case nodeHPBonus2Desc
    case nodeArmor1
    case nodeArmor1Desc
    case nodeHPRegen1
    case nodeHPRegen1Desc
    case nodeVitality
    case nodeVitalityDesc
    case nodeImmortal
    case nodeImmortalDesc

    // Economy nodes
    case nodeGoldBonus1
    case nodeGoldBonus1Desc
    case nodeGoldBonus2
    case nodeGoldBonus2Desc
    case nodeLootChance1
    case nodeLootChance1Desc
    case nodeXPBonus1
    case nodeXPBonus1Desc
    case nodeMidas
    case nodeMidasDesc
    case nodeJackpot
    case nodeJackpotDesc

    // Ability nodes
    case nodeCooldownReduction1
    case nodeCooldownReduction1Desc
    case nodeCooldownReduction2
    case nodeCooldownReduction2Desc
    case nodeSkillPower1
    case nodeSkillPower1Desc
    case nodeEnergyRegen1
    case nodeEnergyRegen1Desc
    case nodeAbilityMastery
    case nodeAbilityMasteryDesc
    case nodeArcanePower
    case nodeArcanePowerDesc

    // Effect descriptions
    case effectDamageMultiplier
    case effectCritChance
    case effectAttackSpeed
    case effectMaxHP
    case effectDamageReduction
    case effectHPRegen
    case effectGoldMultiplier
    case effectLootChance
    case effectXPMultiplier
    case effectCooldownReduction
    case effectSkillDamage
    case effectEnergyRegen

    // MARK: - Settings Tabs
    case tabGeneral
    case tabGame
    case tabEquipment
    case tabTools
    case tabSessions

    // MARK: - Session Monitor
    case activeSessions
    case noActiveSessions
    case sessionCount
    case moreSessions
    case sessionActive
    case sessionIdle
    case sessionUnknownProject
    case sessionUnknownTokenCount
    case sessionUnknownTokenUsage
    case showSessions
    case showBattle
    case skillPassiveTree
    case skillActiveSkills
    case skillSharedBudget
    case skillMigrationMessage
    case skillMigrationAcknowledged
    case skillRefundBlocked
    case skillNoPoints
    case skillRefundAvailable
    case skillPercentBonus
    case skillPercentReduction
    case skillHPPerSecond
    case skillCurrentEffect
    case skillNextEffect
    case skillActiveCurrent
    case skillActiveNext
    case skillCastDetails
    case autoCastPriorityDetail
    case skillEnergyStatus
}

enum L10n {
    static func text(_ key: L10nKey) -> String {
        let language = AppLanguage.load()
        return translations[language]?[key] ?? translations[.english]?[key] ?? key.rawValue
    }

    static func translation(for key: L10nKey, language: AppLanguage) -> String? {
        translations[language]?[key]
    }

    static func string(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        NSString(format: text(key), arguments: getVaList(arguments)) as String
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .english: [
            .openVibeHero: "Open Vibe Hero",
            .openSettings: "Settings...",
            .quitVibeHero: "Quit Vibe Hero",
            .settingsTitle: "Vibe Hero Settings",
            .language: "Language",
            .heroRole: "Hero Role",
            .display: "Display",
            .skills: "Skills",
            .inDevelopment: "In development",
            .inDevelopmentSkillsDetail: "Skills are not playable yet.",
            .inDevelopmentEquipmentDetail: "Equipment is not playable yet.",
            .tokenHooks: "Token Sources",
            .tokenHooksDetail: "Read supported local logs automatically, or install optional hooks for other sources.",
            .installHook: "Install",
            .hookInstalled: "Installed",
            .hookInstallFailed: "Install failed: %@",
            .hookInstalledDetail: "Hook installed. Restart or reopen the tool if it is already running.",
            .hookClaudeDetail: "Adds Claude Code hooks to ~/.claude/settings.json.",
            .hookCodexDetail: "Adds Codex hooks to ~/.codex/hooks.json.",
            .hookOpenCodeDetail: "Adds an OpenCode plugin to ~/.config/opencode/plugins.",
            .hookOpenClawDetail: "Adds a hook script to ~/.openclaw/hooks.",
            .hookHermesDetail: "Adds a hook script to ~/.hermes/hooks.",
            .hookKimiDetail: "Reading today's usage from native Kimi logs. No installation needed.",
            .nativeAutomatic: "Auto-read",
            .nativeWaiting: "Waiting for usage",
            .nativeWaitingDetail: "Automatically reads native Kimi logs. Waiting for today's usage data.",
            .nativeReceiving: "Usage data received",
            .followActiveDisplay: "Follow Active Display",
            .fixedToDisplay: "Fixed to %@",
            .followsActiveDisplay: "The notch follows the active display.",
            .pinnedDisplayMissing: "The pinned display is not connected. The notch is temporarily using the active display.",
            .fullScreen: "Full Screen",
            .hideInFullScreen: "Hide in full screen",
            .hideInFullScreenDetail: "Automatically hides the notch while an app is full screen. Works on displays with and without a notch.",
            .skillPointsAvailable: "%d skill points available",
            .oneSkillPointAvailable: "1 skill point available",
            .skillPointShort: "1 skill pt",
            .skillPointsShort: "%d skill pts",
            .skillEnergyPercent: "Skill %d/100 (%d%%)",
            .skillReadyStatus: "Ready: %@",
            .skillCooldownStatus: "Skill cooldown %ds",
            .noSkillEquipped: "Unlock a skill",
            .noSkillEnabled: "Enable Auto Cast",
            .autoCast: "Auto Cast",
            .locked: "Locked",
            .unlock: "Unlock",
            .upgrade: "Upgrade",
            .maxed: "Maxed",
            .requiresButton: "Requires",
            .rank: "Rank %d/%d",
            .tier: "Tier %d",
            .requiresPrefix: "Requires: %@",
            .effectPrefix: "Effect: %@",
            .unlocksAtLevel: "Unlocks at LV %d",
            .requiresSkillRank: "Requires %@ R%d",
            .appTitleWithRole: "Vibe Hero · %@",
            .todayTokens: "Today %@",
            .xpPerMinute: "Token rate %@/min",
            .noData: "NO DATA",
            .noLocalUsage: "No local usage",
            .waiting: "Waiting",
            .noLocalTokenEvents: "No local token events found today",
            .tokenStreamStatus: "Token stream damages monsters",
            .watchingSourceLogs: "Watching %@ token logs",
            .defeatedMonster: "Token stream defeated %@",
            .sourceUsageTokens: "%@ usage +%@ tokens",
            .skillCasting: "Casting %@",
            .skillCastDefeated: "%@ defeated %@ · +%d XP",
            .defeatedMonsterXP: "Defeated %@ · +%d XP",
            .levelUpFromMonsterXP: "Defeated %@ · +%d XP · LV %d",
            .levelUpSkillPoint: "Level up to LV %d. Skill point gained",
            .sustainedDefeatedMonster: "Sustained token fire defeated %@",
            .monsterRespawned: "%@ respawned",
            .noRecentTokenSpend: "No recent token spend. %@ is circling",
            .idleTooLong: "Idle too long. Next counterattack soon",
            .idleCounterattacks: "Idle %ds. %@ counterattacks",
            .monsterAttackingNoTokens: "No token spend. %@ attacks",
            .heroDefeated: "Defeated. Spend tokens to revive",
            .heroReviving: "Token stream revived the hero",
            .monsterHP: "%@ HP %@/%@ (%d%%)",
            .hpPercent: "HP %@/%d (%d%%)",
            .xpPercent: "XP %@/%@ (%d%%)",
            .hpDamage: "HP-%d",
            .hpDamageDecimal: "HP-%.1f",
            .hpHeal: "HP+%d",
            .todayTokensGold: "Today %@ · G %d",
            .tokenRateBuff: "Token %@/min · ATK %ds",
            .lootHealthPotion: "Health Potion",
            .lootPowerBoost: "Power Boost",
            .lootGold: "Gold",
            .lootPotionSummary: "%@ HP+%d",
            .lootBuffSummary: "%@ +25%% (%ds)",
            .lootGoldSummary: "+%d Gold",
            .defeatedMonsterXPAndLoot: "Defeated %@ · +%d XP · %@",

            .rolePMLabel: "PM",
            .roleDesignerLabel: "Designer",
            .roleArtistLabel: "Artist",
            .roleEngineerLabel: "Engineer",
            .roleQALabel: "QA",
            .roleOtherLabel: "Other",
            .rolePMDetail: "PM · steady planning rhythm",
            .roleDesignerDetail: "Designer · maps the next move",
            .roleArtistDetail: "Artist · stronger idle shield",
            .roleEngineerDetail: "Engineer · higher damage from token bursts",
            .roleQADetail: "QA · safer HP during quiet periods",
            .roleOtherDetail: "Adventurer · balanced growth",
            .rolePMPerk: "Balanced attack and idle defense",
            .roleDesignerPerk: "Violet flow-board attack style",
            .roleArtistPerk: "Idle damage -18%",
            .roleEngineerPerk: "Token strike damage +15%",
            .roleQAPerk: "Idle damage -25%",
            .roleOtherPerk: "No modifier",

            .skillPulseBladeName: "Pulse Blade",
            .skillTokenVolleyName: "Token Volley",
            .skillArcBurstName: "Arc Burst",
            .skillWraithMarkName: "Wraith Mark",
            .skillNovaStormName: "Nova Storm",
            .skillOverclockCoreName: "Overclock Core",
            .skillPulseBladeSummary: "Sharpens the energy laser for heavier hits.",
            .skillTokenVolleySummary: "Compresses more token energy into each laser.",
            .skillArcBurstSummary: "Stabilizes the beam with focused arc energy.",
            .skillWraithMarkSummary: "Marks the target to amplify laser damage.",
            .skillNovaStormSummary: "Channels nova energy through the laser core.",
            .skillOverclockCoreSummary: "Overclocks the laser emitter for stronger hits.",
            .skillPulseBladeEffect: "+5% laser damage per rank",
            .skillTokenVolleyEffect: "+4% laser damage per rank",
            .skillArcBurstEffect: "+3% laser damage per rank",
            .skillWraithMarkEffect: "+6% laser damage per rank",
            .skillNovaStormEffect: "+7% laser damage per rank",
            .skillOverclockCoreEffect: "+4% laser damage per rank",

            .monsterPromptWraith: "Prompt Wraith",
            .monsterCacheGolem: "Cache Golem",
            .monsterTokenSlime: "Token Slime",
            .monsterNullSentinel: "Null Sentinel",
            .monsterPromptWraithShort: "Wraith",
            .monsterCacheGolemShort: "Golem",
            .monsterTokenSlimeShort: "Slime",
            .monsterNullSentinelShort: "Sentinel",

            .lootEquipment: "Equipment",
            .rarityCommon: "Common",
            .rarityUncommon: "Uncommon",
            .rarityRare: "Rare",
            .rarityEpic: "Epic",
            .rarityLegendary: "Legendary",
            .slotWeapon: "Weapon",
            .slotArmor: "Armor",
            .slotCharm: "Charm",
            .equipmentName: "%1$@ %2$@",
            .equipmentBonusWeapon: "ATK +%d%%",
            .equipmentBonusArmor: "DEF +%d%%",
            .equipmentBonusCharm: "CHG +%d%%",
            .lootEquipmentSummary: "%1$@ %2$@",
            .equipmentEquipped: "Equipped %@",
            .equipmentSalvaged: "%@ salvaged · +%d G",
            .equipmentSectionTitle: "Equipment",
            .hudLevel: "LV %d",
            .hudLevelStage: "%@ · %@",
            .hudTokenTotal: "Tokens %@",
            .hudGoldTotal: "Gold %@",
            .hudTokenDetails: "Today: %@ tokens · %@ tokens/min",
            .hudActive: "Active",
            .hudIdle: "Idle",
            .hudWaiting: "Waiting for tokens",
            .hudDefeated: "Defeated",
            .hudHeroStatus: "%@: %@",
            .hudHeroHealth: "HP %@/%@",
            .hudMonsterHealth: "%@ %@/%@",
            .campEnter: "Rest at camp",
            .campLeave: "Leave camp",
            .campStatusShort: "At camp",
            .campResting: "Resting · +0.5 HP/s",
            .campRecovering: "Recovering · revive at 28% HP",
            .campPausedSkill: "Camp · energy %@/%@ · Auto Cast paused",
            .campRules: "Camp pauses combat, enemy recovery and Auto Cast. Token usage still counts; earned damage waits until you leave. Learned skills still gain energy, up to 40,000. Recover 0.5 HP per second; if defeated, revive at 28% HP and remain at camp. Leave camp to resume combat.",
            .monsterShieldStatus: "Shield %.0f/%.0f",
            .monsterShieldDetails: "Damage depletes the shield before monster HP. Each new Golem starts with its own shield.",
            .monsterRegenerationStatus: "Idle heal +%.1f%% HP/s",
            .monsterRegenerationPausedStatus: "Idle heal paused · %.1f%% HP/s",
            .monsterRegenerationDetails: "After 15 seconds without token activity, a living Slime recovers maximum HP each second at this rate. Token activity or camping stops recovery.",
            .bossPhase1Status: "Phase 1",
            .bossPhase2Status: "Phase 2 · attack +%d%%",
            .bossPhaseDetails: "At 50% HP, the boss enters phase 2 and deals 50% more damage. This phase lasts until the boss is defeated.",
            .shieldAbsorbed: "Shield absorbed %.0f",
            .roleStatsShort: "Attack %+d%%\nDamage taken %+d%%",
            .roleChoiceAccessibility: "%@. %@. %@",
            .equipmentGoldBalance: "Gold %@",
            .equipmentBoostActive: "Power boost: damage +%d%% · %d sec remaining",
            .equipmentBoostInactive: "No temporary damage boost.",
            .equipmentRules: "Better drops equip automatically. Equal or lower quality drops become gold. Upgrades raise the equipped item by one quality tier and apply immediately.",
            .equipmentRecentRewards: "Recent rewards · latest 40",
            .equipmentHistoryEmpty: "Rewards and upgrades will appear here after combat or a purchase.",
            .equipmentCurrentState: "Current: %@ · %@",
            .equipmentNextState: "Next: %@ · %@",
            .equipmentSlotEmpty: "Empty slot",
            .equipmentEmptyReason: "Find equipment in combat before upgrading this slot.",
            .equipmentMaxedReason: "Maximum quality reached.",
            .equipmentInsufficientGold: "Need %@ more gold.",
            .equipmentUpgradeAction: "Upgrade",
            .equipmentUpgradePrice: "Upgrade · %@ G",
            .equipmentUpgradeAccessibility: "Upgrade %@ to %@ for %@ gold",
            .equipmentUnavailableAccessibility: "%@: %@",
            .equipmentDetailedWeapon: "Damage +%d%%",
            .equipmentDetailedArmor: "Idle damage taken −%d%%",
            .equipmentDetailedCharm: "Skill energy gain +%d%%",
            .equipmentHistoryPotion: "Potion · +%@ HP",
            .equipmentHistoryBoost: "Power boost · +%d sec",
            .equipmentHistoryGold: "Gold · +%d G",
            .equipmentHistoryBossGold: "Boss reward · +%d G",
            .equipmentHistoryUpgrade: "%@ upgraded · −%d G",
            .lootPotionExactSummary: "Potion +%@ HP",
            .lootPotionExactFloat: "+%@ HP",
            .stageTag: "STAGE %d",
            .stageTagBoss: "STAGE %d · BOSS",
            .stageReached: "Stage %d reached",
            .bossAppears: "BOSS %@ appears!",
            .bossMonsterName: "BOSS %@",
            .comboText: "COMBO x%d",
            .critLabel: "CRIT",
            .levelUpBanner: "LEVEL UP!",

            .backdrop: "Scene",
            .backdropMidnightForest: "Midnight Forest",
            .backdropCrystalCave: "Crystal Cave",
            .backdropSunsetDunes: "Sunset Dunes",
            .backdropNeonCity: "Neon City",

            // MARK: - Skill Tree
            .skillTreeAttack: "Attack",
            .skillTreeDefense: "Defense",
            .skillTreeEconomy: "Economy",
            .skillTreeAbility: "Ability",
            .availableSkillPoints: "Available Points: %d",
            .selectNodePrompt: "Select a node",
            .currentLevel: "Level: %d/%d",
            .requiresHeroLevel: "Hero Lv%d",
            .requiresParent: "Requires %@",
            .nodeUpgrade: "Upgrade (1 pt)",
            .nodeDowngrade: "Refund 1 pt",
            .nodeMaxed: "Maxed",

            // Attack nodes
            .nodeAttackPower1: "Power Strike I",
            .nodeAttackPower1Desc: "Increase damage dealt by token attacks and skills.",
            .nodeAttackPower2: "Power Strike II",
            .nodeAttackPower2Desc: "Further increase attack damage",
            .nodeCritChance1: "Critical Eye",
            .nodeCritChance1Desc: "Increase critical hit chance",
            .nodeAttackSpeed1: "Offensive Charge",
            .nodeAttackSpeed1Desc: "Gain more skill energy from each verified token.",
            .nodeAttackMastery: "Attack Mastery",
            .nodeAttackMasteryDesc: "Significantly boost attack power",
            .nodeBerserk: "Berserk",
            .nodeBerserkDesc: "Massive damage boost",

            // Defense nodes
            .nodeHPBonus1: "Vitality I",
            .nodeHPBonus1Desc: "Increase maximum HP.",
            .nodeHPBonus2: "Vitality II",
            .nodeHPBonus2Desc: "Further increase max HP",
            .nodeArmor1: "Iron Skin",
            .nodeArmor1Desc: "Reduce damage taken",
            .nodeHPRegen1: "Regeneration",
            .nodeHPRegen1Desc: "Restore a fixed amount of HP each second while alive.",
            .nodeVitality: "Vital Force",
            .nodeVitalityDesc: "Greatly increase max HP",
            .nodeImmortal: "Immortal",
            .nodeImmortalDesc: "Massive damage reduction",

            // Economy nodes
            .nodeGoldBonus1: "Gold Hunter I",
            .nodeGoldBonus1Desc: "Increase gold gain by 10%",
            .nodeGoldBonus2: "Gold Hunter II",
            .nodeGoldBonus2Desc: "Further increase gold gain",
            .nodeLootChance1: "Lucky Find",
            .nodeLootChance1Desc: "Turn otherwise empty drops into a reward.",
            .nodeXPBonus1: "Wisdom",
            .nodeXPBonus1Desc: "Increase XP gain",
            .nodeMidas: "Midas Touch",
            .nodeMidasDesc: "Greatly increase gold gain",
            .nodeJackpot: "Jackpot",
            .nodeJackpotDesc: "Greatly improve the chance to rescue an empty drop.",

            // Ability nodes
            .nodeCooldownReduction1: "Quick Cast I",
            .nodeCooldownReduction1Desc: "Reduce skill cooldown",
            .nodeCooldownReduction2: "Quick Cast II",
            .nodeCooldownReduction2Desc: "Further reduce cooldown",
            .nodeSkillPower1: "Empowered",
            .nodeSkillPower1Desc: "Increase skill damage",
            .nodeEnergyRegen1: "Energy Flow",
            .nodeEnergyRegen1Desc: "Amplify energy gained from verified token usage.",
            .nodeAbilityMastery: "Ability Mastery",
            .nodeAbilityMasteryDesc: "Greatly boost skill power",
            .nodeArcanePower: "Arcane Power",
            .nodeArcanePowerDesc: "Massive cooldown reduction",

            // Effect descriptions
            .effectDamageMultiplier: "Damage",
            .effectCritChance: "Crit Chance",
            .effectAttackSpeed: "Offensive charge",
            .effectMaxHP: "Max HP",
            .effectDamageReduction: "Damage Reduction",
            .effectHPRegen: "HP Regen",
            .effectGoldMultiplier: "Gold Gain",
            .effectLootChance: "Empty-drop rescue chance",
            .effectXPMultiplier: "XP Gain",
            .effectCooldownReduction: "Cooldown",
            .effectSkillDamage: "Skill Damage",
            .effectEnergyRegen: "Token energy gain",

            // Settings Tabs
            .tabGeneral: "General",
            .tabGame: "Game",
            .tabEquipment: "Equipment",
            .tabTools: "Tools",
            .tabSessions: "Sessions",

            // Session Monitor
            .activeSessions: "Active IDE Sessions",
            .noActiveSessions: "No active sessions",
            .sessionCount: "%d sessions",
            .moreSessions: "+%d more",
            .sessionActive: "● Active",
            .sessionIdle: "○ Idle",
            .sessionUnknownProject: "Unknown project",
            .sessionUnknownTokenCount: "—",
            .sessionUnknownTokenUsage: "No verified token usage",
            .showSessions: "Show sessions",
            .showBattle: "Show battle",
            .skillPassiveTree: "Passive tree",
            .skillActiveSkills: "Active skills",
            .skillSharedBudget: "Active and passive ranks share one point per hero level. Each rank costs 1 point; refunds are free.",
            .skillMigrationMessage: "Your previous skill ranks are preserved. %d extra points preserve prior allocations; all ranks can be refunded into the shared budget.",
            .skillMigrationAcknowledged: "Got it",
            .skillRefundBlocked: "Refund %@ first; it needs this rank.",
            .skillNoPoints: "No points available. Level up or refund another rank.",
            .skillRefundAvailable: "Refund returns 1 point to the shared budget.",
            .skillPercentBonus: "+%.1f%%",
            .skillPercentReduction: "−%.1f%%",
            .skillHPPerSecond: "%.2f HP/sec",
            .skillCurrentEffect: "Current: %@",
            .skillNextEffect: "Next: %@",
            .skillActiveCurrent: "Current: passive damage +%.1f%% · base cast %@",
            .skillActiveNext: "Next: passive damage +%.1f%% · base cast %@",
            .skillCastDetails: "Energy %@ · Cooldown %.1fs",
            .autoCastPriorityDetail: "Save energy for the highest-tier ready skill. While it cools down, other enabled skills can cast. Verified tokens charge energy; casting uses damage and skill bonuses.",
            .skillEnergyStatus: "%@ / %@ energy · %@"
        ],
        .simplifiedChinese: [
            .openVibeHero: "打开 Vibe Hero",
            .openSettings: "设置...",
            .quitVibeHero: "退出 Vibe Hero",
            .settingsTitle: "Vibe Hero 设置",
            .language: "语言",
            .heroRole: "英雄角色",
            .display: "显示器",
            .skills: "技能",
            .inDevelopment: "开发中",
            .inDevelopmentSkillsDetail: "技能功能还在开发中，暂不可用。",
            .inDevelopmentEquipmentDetail: "装备功能还在开发中，暂不可用。",
            .tokenHooks: "Token 数据源",
            .tokenHooksDetail: "自动读取支持的本地日志，也可为其他数据源安装可选 hook。",
            .installHook: "安装",
            .hookInstalled: "已安装",
            .hookInstallFailed: "安装失败：%@",
            .hookInstalledDetail: "Hook 已安装。如果工具正在运行，请重启或重新打开它。",
            .hookClaudeDetail: "向 ~/.claude/settings.json 添加 Claude Code hooks。",
            .hookCodexDetail: "向 ~/.codex/hooks.json 添加 Codex hooks。",
            .hookOpenCodeDetail: "向 ~/.config/opencode/plugins 添加 OpenCode plugin。",
            .hookOpenClawDetail: "向 ~/.openclaw/hooks 添加 Hook 脚本。",
            .hookHermesDetail: "向 ~/.hermes/hooks 添加 Hook 脚本。",
            .hookKimiDetail: "正在读取 Kimi 原生日志中的今日用量，无需安装。",
            .nativeAutomatic: "自动读取",
            .nativeWaiting: "等待用量数据",
            .nativeWaitingDetail: "自动读取 Kimi 原生日志，等待今日用量数据。",
            .nativeReceiving: "已收到用量数据",
            .followActiveDisplay: "跟随当前显示器",
            .fixedToDisplay: "固定到 %@",
            .followsActiveDisplay: "刘海窗口会跟随当前显示器。",
            .pinnedDisplayMissing: "固定的显示器未连接，刘海窗口暂时使用当前显示器。",
            .fullScreen: "全屏",
            .hideInFullScreen: "全屏时隐藏刘海",
            .hideInFullScreenDetail: "有应用进入全屏时自动隐藏刘海窗口，有无刘海（灵动岛）的屏幕都适用。",
            .skillPointsAvailable: "%d 个技能点可用",
            .oneSkillPointAvailable: "1 个技能点可用",
            .skillPointShort: "1 技能点",
            .skillPointsShort: "%d 技能点",
            .skillEnergyPercent: "技能 %d/100 (%d%%)",
            .skillReadyStatus: "已就绪：%@",
            .skillCooldownStatus: "技能冷却 %d 秒",
            .noSkillEquipped: "解锁一个技能",
            .noSkillEnabled: "启用自动释放",
            .autoCast: "自动释放",
            .locked: "未解锁",
            .unlock: "解锁",
            .upgrade: "升级",
            .maxed: "已满级",
            .requiresButton: "需前置",
            .rank: "等级 %d/%d",
            .tier: "阶层 %d",
            .requiresPrefix: "需要：%@",
            .effectPrefix: "效果：%@",
            .unlocksAtLevel: "LV %d 解锁",
            .requiresSkillRank: "需要 %@ R%d",
            .appTitleWithRole: "Vibe Hero · %@",
            .todayTokens: "今日 %@",
            .xpPerMinute: "Token 速率 %@/分钟",
            .noData: "无数据",
            .noLocalUsage: "无本地用量",
            .waiting: "等待中",
            .noLocalTokenEvents: "今天未找到本地 token 事件",
            .tokenStreamStatus: "Token 消耗会对怪物造成伤害",
            .watchingSourceLogs: "正在观察 %@ token 日志",
            .defeatedMonster: "Token 流击败了 %@",
            .sourceUsageTokens: "%@ 用量 +%@ tokens",
            .skillCasting: "正在施放 %@",
            .skillCastDefeated: "%@ 击败了 %@ · +%d XP",
            .defeatedMonsterXP: "击败 %@ · +%d XP",
            .levelUpFromMonsterXP: "击败 %@ · +%d XP · LV %d",
            .levelUpSkillPoint: "升级到 LV %d，获得技能点",
            .sustainedDefeatedMonster: "持续 token 火力击败了 %@",
            .monsterRespawned: "%@ 已重生",
            .noRecentTokenSpend: "最近没有 token 消耗，%@ 正在盘旋",
            .idleTooLong: "闲置过久，下次反击即将到来",
            .idleCounterattacks: "闲置 %d 秒，%@ 发起反击",
            .monsterAttackingNoTokens: "没有 token 消耗，%@ 发起攻击",
            .heroDefeated: "已被击败，消耗 token 可复活",
            .heroReviving: "Token 流复活了英雄",
            .monsterHP: "%@ HP %@/%@ (%d%%)",
            .hpPercent: "HP %@/%d (%d%%)",
            .xpPercent: "XP %@/%@ (%d%%)",
            .hpDamage: "HP-%d",
            .hpDamageDecimal: "HP-%.1f",
            .hpHeal: "HP+%d",
            .todayTokensGold: "今日 %@ · 金币 %d",
            .tokenRateBuff: "Token %@/分钟 · 攻击 %d秒",
            .lootHealthPotion: "生命药水",
            .lootPowerBoost: "力量增益",
            .lootGold: "金币",
            .lootPotionSummary: "%@ HP+%d",
            .lootBuffSummary: "%@ +25%%（%d秒）",
            .lootGoldSummary: "+%d 金币",
            .defeatedMonsterXPAndLoot: "击败 %@ · +%d XP · %@",

            .rolePMLabel: "PM",
            .roleDesignerLabel: "设计师",
            .roleArtistLabel: "美术",
            .roleEngineerLabel: "工程师",
            .roleQALabel: "QA",
            .roleOtherLabel: "其他",
            .rolePMDetail: "PM · 稳定规划节奏",
            .roleDesignerDetail: "设计师 · 标出下一步行动",
            .roleArtistDetail: "美术 · 更强的闲置护盾",
            .roleEngineerDetail: "工程师 · token 爆发造成更高伤害",
            .roleQADetail: "QA · 安静期 HP 更安全",
            .roleOtherDetail: "冒险者 · 均衡成长",
            .rolePMPerk: "攻击和闲置防御均衡",
            .roleDesignerPerk: "紫色流程板攻击风格",
            .roleArtistPerk: "闲置伤害 -18%",
            .roleEngineerPerk: "Token 打击伤害 +15%",
            .roleQAPerk: "闲置伤害 -25%",
            .roleOtherPerk: "无修正",

            .skillPulseBladeName: "脉冲刃",
            .skillTokenVolleyName: "Token 齐射",
            .skillArcBurstName: "电弧爆裂",
            .skillWraithMarkName: "幽影标记",
            .skillNovaStormName: "新星风暴",
            .skillOverclockCoreName: "超频核心",
            .skillPulseBladeSummary: "强化能量激光，提高单次命中威力。",
            .skillTokenVolleySummary: "将更多 token 能量压缩进每次激光攻击。",
            .skillArcBurstSummary: "使用聚焦电弧稳定光束。",
            .skillWraithMarkSummary: "标记目标，放大激光伤害。",
            .skillNovaStormSummary: "将新星能量导入激光核心。",
            .skillOverclockCoreSummary: "超频激光发射器，提高命中威力。",
            .skillPulseBladeEffect: "每级 +5% 激光伤害",
            .skillTokenVolleyEffect: "每级 +4% 激光伤害",
            .skillArcBurstEffect: "每级 +3% 激光伤害",
            .skillWraithMarkEffect: "每级 +6% 激光伤害",
            .skillNovaStormEffect: "每级 +7% 激光伤害",
            .skillOverclockCoreEffect: "每级 +4% 激光伤害",

            .monsterPromptWraith: "提示幽影",
            .monsterCacheGolem: "缓存魔像",
            .monsterTokenSlime: "Token 史莱姆",
            .monsterNullSentinel: "空值哨兵",
            .monsterPromptWraithShort: "幽影",
            .monsterCacheGolemShort: "魔像",
            .monsterTokenSlimeShort: "史莱姆",
            .monsterNullSentinelShort: "哨兵",

            .lootEquipment: "装备",
            .rarityCommon: "普通",
            .rarityUncommon: "优秀",
            .rarityRare: "稀有",
            .rarityEpic: "史诗",
            .rarityLegendary: "传说",
            .slotWeapon: "武器",
            .slotArmor: "护甲",
            .slotCharm: "护符",
            .equipmentName: "%1$@%2$@",
            .equipmentBonusWeapon: "攻击 +%d%%",
            .equipmentBonusArmor: "防御 +%d%%",
            .equipmentBonusCharm: "充能 +%d%%",
            .lootEquipmentSummary: "%1$@ %2$@",
            .equipmentEquipped: "已装备 %@",
            .equipmentSalvaged: "%@ 已折算 · +%d 金币",
            .equipmentSectionTitle: "装备",
            .hudLevel: "等级 %d",
            .hudLevelStage: "%@ · %@",
            .hudTokenTotal: "Token %@",
            .hudGoldTotal: "金币 %@",
            .hudTokenDetails: "今日：%@ Token · 每分钟 %@ Token",
            .hudActive: "活跃",
            .hudIdle: "空闲",
            .hudWaiting: "等待 Token",
            .hudDefeated: "已倒下",
            .hudHeroStatus: "%@：%@",
            .hudHeroHealth: "生命 %@/%@",
            .hudMonsterHealth: "%@ %@/%@",
            .campEnter: "进入营地休息",
            .campLeave: "离开营地",
            .campStatusShort: "营地休息",
            .campResting: "休息中 · 每秒恢复 0.5 生命",
            .campRecovering: "静养中 · 生命达到 28% 后复活",
            .campPausedSkill: "营地 · 能量 %@/%@ · 自动施法暂停",
            .campRules: "营地暂停战斗、敌人恢复与自动施法。Token 继续统计，获得的伤害暂存至离开营地；已学习技能继续充能，上限 40,000。每秒恢复 0.5 生命，倒下时恢复至 28% 生命后复活，并继续留在营地。离开营地后恢复战斗。",
            .monsterShieldStatus: "护盾 %.0f/%.0f",
            .monsterShieldDetails: "伤害先消耗护盾，再扣除敌人生命。每只新魔像拥有独立护盾。",
            .monsterRegenerationStatus: "闲置自愈 · 每秒 +%.1f%% 生命",
            .monsterRegenerationPausedStatus: "自愈暂停 · 每秒 %.1f%% 生命",
            .monsterRegenerationDetails: "连续 15 秒没有 Token 活动后，存活的史莱姆每秒按此比例恢复最大生命。Token 活动或进入营地会停止恢复。",
            .bossPhase1Status: "第一阶段",
            .bossPhase2Status: "第二阶段 · 攻击 +%d%%",
            .bossPhaseDetails: "生命降至 50% 时，首领进入第二阶段，造成的伤害提高 50%，直至被击败。",
            .shieldAbsorbed: "护盾吸收 %.0f",
            .roleStatsShort: "伤害 %+d%%\n闲置受伤 %+d%%",
            .roleChoiceAccessibility: "%@。%@。%@",
            .equipmentGoldBalance: "金币 %@",
            .equipmentBoostActive: "强攻效果：伤害 +%d%% · 剩余 %d 秒",
            .equipmentBoostInactive: "当前没有临时伤害增益。",
            .equipmentRules: "更高品质的掉落会自动装备，同级或更低品质会分解为金币。升级会使当前装备提升一个品质，并立即生效。",
            .equipmentRecentRewards: "最近奖励 · 保留最新 40 条",
            .equipmentHistoryEmpty: "战斗获得的奖励和购买的升级将记录在这里。",
            .equipmentCurrentState: "当前：%@ · %@",
            .equipmentNextState: "下一级：%@ · %@",
            .equipmentSlotEmpty: "尚未装备",
            .equipmentEmptyReason: "先在战斗中获得此部位的装备，再使用金币升级。",
            .equipmentMaxedReason: "已达到最高品质。",
            .equipmentInsufficientGold: "还需要 %@ 金币。",
            .equipmentUpgradeAction: "升级",
            .equipmentUpgradePrice: "升级 · %@ 金币",
            .equipmentUpgradeAccessibility: "升级%@至%@，花费 %@ 金币",
            .equipmentUnavailableAccessibility: "%@：%@",
            .equipmentDetailedWeapon: "伤害 +%d%%",
            .equipmentDetailedArmor: "闲置受到伤害 −%d%%",
            .equipmentDetailedCharm: "技能能量获取 +%d%%",
            .equipmentHistoryPotion: "药水 · 恢复 %@ 生命",
            .equipmentHistoryBoost: "强攻 · 增加 %d 秒",
            .equipmentHistoryGold: "金币 · +%d",
            .equipmentHistoryBossGold: "首领奖励 · +%d 金币",
            .equipmentHistoryUpgrade: "%@升级 · −%d 金币",
            .lootPotionExactSummary: "药水恢复 %@ 生命",
            .lootPotionExactFloat: "+%@ 生命",
            .stageTag: "第 %d 关",
            .stageTagBoss: "第 %d 关 · BOSS",
            .stageReached: "进入第 %d 关",
            .bossAppears: "BOSS %@ 现身！",
            .bossMonsterName: "BOSS %@",
            .comboText: "连击 x%d",
            .critLabel: "暴击",
            .levelUpBanner: "升级！",

            .backdrop: "背景场景",
            .backdropMidnightForest: "午夜森林",
            .backdropCrystalCave: "水晶洞窟",
            .backdropSunsetDunes: "落日沙丘",
            .backdropNeonCity: "霓虹都市",

            // MARK: - 技能树
            .skillTreeAttack: "攻击",
            .skillTreeDefense: "防御",
            .skillTreeEconomy: "经济",
            .skillTreeAbility: "技能",
            .availableSkillPoints: "可用点数: %d",
            .selectNodePrompt: "选择一个节点",
            .currentLevel: "等级: %d/%d",
            .requiresHeroLevel: "需要英雄等级 %d",
            .requiresParent: "需要 %@",
            .nodeUpgrade: "升级（1 点）",
            .nodeDowngrade: "退还 1 点",
            .nodeMaxed: "已满级",

            // 攻击节点
            .nodeAttackPower1: "强力打击 I",
            .nodeAttackPower1Desc: "提高 Token 攻击与主动技能的伤害。",
            .nodeAttackPower2: "强力打击 II",
            .nodeAttackPower2Desc: "进一步提升攻击力",
            .nodeCritChance1: "暴击之眼",
            .nodeCritChance1Desc: "提升暴击率",
            .nodeAttackSpeed1: "攻势充能",
            .nodeAttackSpeed1Desc: "每个已验证的 Token 提供更多技能能量。",
            .nodeAttackMastery: "攻击精通",
            .nodeAttackMasteryDesc: "大幅提升攻击力",
            .nodeBerserk: "狂暴",
            .nodeBerserkDesc: "攻击力暴增",

            // 防御节点
            .nodeHPBonus1: "生命力 I",
            .nodeHPBonus1Desc: "提高最大生命值。",
            .nodeHPBonus2: "生命力 II",
            .nodeHPBonus2Desc: "进一步提升最大生命值",
            .nodeArmor1: "铁皮皮肤",
            .nodeArmor1Desc: "减少受到的伤害",
            .nodeHPRegen1: "生命恢复",
            .nodeHPRegen1Desc: "存活时每秒恢复固定生命点。",
            .nodeVitality: "生命之力",
            .nodeVitalityDesc: "大幅提升最大生命值",
            .nodeImmortal: "不朽",
            .nodeImmortalDesc: "大幅减少受到伤害",

            // 经济节点
            .nodeGoldBonus1: "黄金猎人 I",
            .nodeGoldBonus1Desc: "金币获取提升 10%",
            .nodeGoldBonus2: "黄金猎人 II",
            .nodeGoldBonus2Desc: "进一步提升金币获取",
            .nodeLootChance1: "幸运发现",
            .nodeLootChance1Desc: "有概率将原本的空掉落补偿为奖励。",
            .nodeXPBonus1: "智慧",
            .nodeXPBonus1Desc: "提升经验获取",
            .nodeMidas: "点金之手",
            .nodeMidasDesc: "大幅提升金币获取",
            .nodeJackpot: "头奖",
            .nodeJackpotDesc: "大幅提高空掉落补偿为奖励的概率。",

            // 技能节点
            .nodeCooldownReduction1: "快速施法 I",
            .nodeCooldownReduction1Desc: "减少技能冷却时间",
            .nodeCooldownReduction2: "快速施法 II",
            .nodeCooldownReduction2Desc: "进一步减少冷却时间",
            .nodeSkillPower1: "技能强化",
            .nodeSkillPower1Desc: "提升技能伤害",
            .nodeEnergyRegen1: "能量流动",
            .nodeEnergyRegen1Desc: "提高已验证 Token 消耗提供的能量。",
            .nodeAbilityMastery: "技能精通",
            .nodeAbilityMasteryDesc: "大幅提升技能威力",
            .nodeArcanePower: "奥术之力",
            .nodeArcanePowerDesc: "大幅减少冷却时间",

            // 效果描述
            .effectDamageMultiplier: "伤害",
            .effectCritChance: "暴击率",
            .effectAttackSpeed: "攻势充能",
            .effectMaxHP: "最大生命",
            .effectDamageReduction: "伤害减免",
            .effectHPRegen: "生命恢复",
            .effectGoldMultiplier: "金币获取",
            .effectLootChance: "空掉落补偿概率",
            .effectXPMultiplier: "经验获取",
            .effectCooldownReduction: "冷却时间",
            .effectSkillDamage: "技能伤害",
            .effectEnergyRegen: "Token 能量增益",

            // 设置标签页
            .tabGeneral: "通用",
            .tabGame: "游戏",
            .tabEquipment: "装备",
            .tabTools: "工具",
            .tabSessions: "会话",

            // 会话监控
            .activeSessions: "活跃 IDE 会话",
            .noActiveSessions: "暂无活跃会话",
            .sessionCount: "%d 个会话",
            .moreSessions: "还有 %d 个",
            .sessionActive: "● 活跃",
            .sessionIdle: "○ 空闲",
            .sessionUnknownProject: "未知项目",
            .sessionUnknownTokenCount: "—",
            .sessionUnknownTokenUsage: "暂无已验证的 Token 用量",
            .showSessions: "显示会话",
            .showBattle: "显示战斗",
            .skillPassiveTree: "被动技能树",
            .skillActiveSkills: "主动技能",
            .skillSharedBudget: "主动和被动技能共用每级 1 点的预算。每阶消耗 1 点，可免费退还。",
            .skillMigrationMessage: "已保留原有技能等级，并补偿 %d 点以保留旧投入。所有等级均可退还到统一点数预算。",
            .skillMigrationAcknowledged: "知道了",
            .skillRefundBlocked: "请先退还 %@，它仍需要此前置等级。",
            .skillNoPoints: "没有可用点数。升级英雄或退还其他技能等级。",
            .skillRefundAvailable: "退款将返还 1 点到统一预算。",
            .skillPercentBonus: "+%.1f%%",
            .skillPercentReduction: "−%.1f%%",
            .skillHPPerSecond: "每秒 %.2f 生命点",
            .skillCurrentEffect: "当前：%@",
            .skillNextEffect: "下一级：%@",
            .skillActiveCurrent: "当前：被动伤害 +%.1f%% · 主动基础伤害 %@",
            .skillActiveNext: "下一级：被动伤害 +%.1f%% · 主动基础伤害 %@",
            .skillCastDetails: "消耗能量 %@ · 冷却 %.1f 秒",
            .autoCastPriorityDetail: "优先积攒能量释放最高阶已就绪技能；其冷却期间可释放其他已启用技能。已验证的 Token 消耗提供能量，施放伤害受伤害与技能加成影响。",
            .skillEnergyStatus: "能量 %@ / %@ · %@"
        ],
        .japanese: [
            .openVibeHero: "Vibe Hero を開く",
            .openSettings: "設定...",
            .quitVibeHero: "Vibe Hero を終了",
            .settingsTitle: "Vibe Hero 設定",
            .language: "言語",
            .heroRole: "ヒーロー役割",
            .display: "ディスプレイ",
            .skills: "スキル",
            .inDevelopment: "開発中",
            .inDevelopmentSkillsDetail: "スキル機能はまだ利用できません。",
            .inDevelopmentEquipmentDetail: "装備機能はまだ利用できません。",
            .tokenHooks: "Token データソース",
            .tokenHooksDetail: "対応するローカルログを自動で読み取ります。他のソースには任意で Hook を追加できます。",
            .installHook: "インストール",
            .hookInstalled: "インストール済み",
            .hookInstallFailed: "インストール失敗：%@",
            .hookInstalledDetail: "Hook をインストールしました。ツールが起動中の場合は再起動してください。",
            .hookClaudeDetail: "~/.claude/settings.json に Claude Code hooks を追加します。",
            .hookCodexDetail: "~/.codex/hooks.json に Codex hooks を追加します。",
            .hookOpenCodeDetail: "~/.config/opencode/plugins に OpenCode plugin を追加します。",
            .hookOpenClawDetail: "~/.openclaw/hooks に Hook スクリプトを追加します。",
            .hookHermesDetail: "~/.hermes/hooks に Hook スクリプトを追加します。",
            .hookKimiDetail: "Kimi の標準ログから本日の使用量を読み取り中です。インストールは不要です。",
            .nativeAutomatic: "自動読み取り",
            .nativeWaiting: "使用量データ待ち",
            .nativeWaitingDetail: "Kimi の標準ログを自動で読み取ります。本日の使用量データを待っています。",
            .nativeReceiving: "使用量データ受信済み",
            .followActiveDisplay: "現在のディスプレイに追従",
            .fixedToDisplay: "%@ に固定",
            .followsActiveDisplay: "ノッチは現在のディスプレイに追従します。",
            .pinnedDisplayMissing: "固定したディスプレイが接続されていません。一時的に現在のディスプレイを使います。",
            .fullScreen: "フルスクリーン",
            .hideInFullScreen: "フルスクリーン時にノッチを隠す",
            .hideInFullScreenDetail: "アプリがフルスクリーンの間、ノッチを自動的に隠します。ノッチの有無にかかわらず動作します。",
            .skillPointsAvailable: "%d スキルポイント使用可能",
            .oneSkillPointAvailable: "1 スキルポイント使用可能",
            .skillPointShort: "1 スキルpt",
            .skillPointsShort: "%d スキルpt",
            .skillEnergyPercent: "スキル %d/100 (%d%%)",
            .skillReadyStatus: "使用可能：%@",
            .skillCooldownStatus: "スキル再使用 %d 秒",
            .noSkillEquipped: "スキルを解放",
            .noSkillEnabled: "自動発動を有効化",
            .autoCast: "自動発動",
            .locked: "ロック中",
            .unlock: "解放",
            .upgrade: "強化",
            .maxed: "最大",
            .requiresButton: "条件あり",
            .rank: "ランク %d/%d",
            .tier: "ティア %d",
            .requiresPrefix: "条件：%@",
            .effectPrefix: "効果：%@",
            .unlocksAtLevel: "LV %d で解放",
            .requiresSkillRank: "%@ R%d が必要",
            .appTitleWithRole: "Vibe Hero · %@",
            .todayTokens: "今日 %@",
            .xpPerMinute: "Token 速度 %@/分",
            .noData: "データなし",
            .noLocalUsage: "ローカル使用量なし",
            .waiting: "待機中",
            .noLocalTokenEvents: "今日のローカル token イベントが見つかりません",
            .tokenStreamStatus: "Token 使用量がモンスターにダメージ",
            .watchingSourceLogs: "%@ の token ログを監視中",
            .defeatedMonster: "Token ストリームが %@ を撃破",
            .sourceUsageTokens: "%@ 使用量 +%@ tokens",
            .skillCasting: "%@ を発動",
            .skillCastDefeated: "%@ が %@ を撃破 · +%d XP",
            .defeatedMonsterXP: "%@ を撃破 · +%d XP",
            .levelUpFromMonsterXP: "%@ を撃破 · +%d XP · LV %d",
            .levelUpSkillPoint: "LV %d に上昇。スキルポイント獲得",
            .sustainedDefeatedMonster: "継続 token 攻撃が %@ を撃破",
            .monsterRespawned: "%@ が復活",
            .noRecentTokenSpend: "最近 token 使用がありません。%@ が旋回中",
            .idleTooLong: "放置が長すぎます。次の反撃が近いです",
            .idleCounterattacks: "%d 秒放置。%@ が反撃",
            .monsterAttackingNoTokens: "token 使用なし。%@ が攻撃",
            .heroDefeated: "敗北。token 使用で復活",
            .heroReviving: "Token ストリームで復活",
            .monsterHP: "%@ HP %@/%@ (%d%%)",
            .hpPercent: "HP %@/%d (%d%%)",
            .xpPercent: "XP %@/%@ (%d%%)",
            .hpDamage: "HP-%d",
            .hpDamageDecimal: "HP-%.1f",
            .hpHeal: "HP+%d",
            .todayTokensGold: "今日 %@ · G %d",
            .tokenRateBuff: "Token %@/分 · 攻撃 %d秒",
            .lootHealthPotion: "回復ポーション",
            .lootPowerBoost: "パワーブースト",
            .lootGold: "ゴールド",
            .lootPotionSummary: "%@ HP+%d",
            .lootBuffSummary: "%@ +25%%（%d秒）",
            .lootGoldSummary: "+%d ゴールド",
            .defeatedMonsterXPAndLoot: "%@ を撃破 · +%d XP · %@",

            .rolePMLabel: "PM",
            .roleDesignerLabel: "デザイナー",
            .roleArtistLabel: "アーティスト",
            .roleEngineerLabel: "エンジニア",
            .roleQALabel: "QA",
            .roleOtherLabel: "その他",
            .rolePMDetail: "PM · 安定した計画リズム",
            .roleDesignerDetail: "デザイナー · 次の一手を描く",
            .roleArtistDetail: "アーティスト · 放置シールド強化",
            .roleEngineerDetail: "エンジニア · token バーストのダメージ上昇",
            .roleQADetail: "QA · 静かな時間の HP が安全",
            .roleOtherDetail: "冒険者 · バランス成長",
            .rolePMPerk: "攻撃と放置防御のバランス型",
            .roleDesignerPerk: "紫のフローボード攻撃スタイル",
            .roleArtistPerk: "放置ダメージ -18%",
            .roleEngineerPerk: "Token 打撃ダメージ +15%",
            .roleQAPerk: "放置ダメージ -25%",
            .roleOtherPerk: "補正なし",

            .skillPulseBladeName: "パルスブレード",
            .skillTokenVolleyName: "Token ボレー",
            .skillArcBurstName: "アークバースト",
            .skillWraithMarkName: "レイスマーク",
            .skillNovaStormName: "ノヴァストーム",
            .skillOverclockCoreName: "オーバークロックコア",
            .skillPulseBladeSummary: "エネルギーレーザーを強化し、命中威力を高める。",
            .skillTokenVolleySummary: "より多くの token エネルギーをレーザーに圧縮する。",
            .skillArcBurstSummary: "収束アークでビームを安定させる。",
            .skillWraithMarkSummary: "対象をマークし、レーザーダメージを増幅する。",
            .skillNovaStormSummary: "ノヴァエネルギーをレーザーコアへ流し込む。",
            .skillOverclockCoreSummary: "レーザーエミッターをオーバークロックし、威力を高める。",
            .skillPulseBladeEffect: "ランクごとにレーザーダメージ +5%",
            .skillTokenVolleyEffect: "ランクごとにレーザーダメージ +4%",
            .skillArcBurstEffect: "ランクごとにレーザーダメージ +3%",
            .skillWraithMarkEffect: "ランクごとにレーザーダメージ +6%",
            .skillNovaStormEffect: "ランクごとにレーザーダメージ +7%",
            .skillOverclockCoreEffect: "ランクごとにレーザーダメージ +4%",

            .monsterPromptWraith: "プロンプトレイス",
            .monsterCacheGolem: "キャッシュゴーレム",
            .monsterTokenSlime: "Token スライム",
            .monsterNullSentinel: "ヌルセンチネル",
            .monsterPromptWraithShort: "レイス",
            .monsterCacheGolemShort: "ゴーレム",
            .monsterTokenSlimeShort: "スライム",
            .monsterNullSentinelShort: "センチネル",

            .lootEquipment: "装備",
            .rarityCommon: "コモン",
            .rarityUncommon: "アンコモン",
            .rarityRare: "レア",
            .rarityEpic: "エピック",
            .rarityLegendary: "レジェンダリー",
            .slotWeapon: "武器",
            .slotArmor: "鎧",
            .slotCharm: "お守り",
            .equipmentName: "%1$@の%2$@",
            .equipmentBonusWeapon: "攻撃 +%d%%",
            .equipmentBonusArmor: "防御 +%d%%",
            .equipmentBonusCharm: "チャージ +%d%%",
            .lootEquipmentSummary: "%1$@ %2$@",
            .equipmentEquipped: "%@ を装備",
            .equipmentSalvaged: "%@ を換金 · +%d G",
            .equipmentSectionTitle: "装備",
            .hudLevel: "LV %d",
            .hudLevelStage: "%@・%@",
            .hudTokenTotal: "Token %@",
            .hudGoldTotal: "ゴールド %@",
            .hudTokenDetails: "今日：%@ Token・毎分 %@ Token",
            .hudActive: "アクティブ",
            .hudIdle: "待機中",
            .hudWaiting: "Token 待ち",
            .hudDefeated: "戦闘不能",
            .hudHeroStatus: "%@：%@",
            .hudHeroHealth: "HP %@/%@",
            .hudMonsterHealth: "%@ %@/%@",
            .campEnter: "キャンプで休む",
            .campLeave: "キャンプを出る",
            .campStatusShort: "キャンプ中",
            .campResting: "休息中・毎秒 HP +0.5",
            .campRecovering: "療養中・HP 28% で復活",
            .campPausedSkill: "キャンプ・エネルギー %@/%@・自動発動停止",
            .campRules: "キャンプでは戦闘、敵の回復、自動発動が停止します。Token は引き続き集計され、獲得したダメージは出発まで蓄積されます。習得済みスキルは最大 40,000 まで充電できます。毎秒 HP が 0.5 回復し、戦闘不能なら HP 28% で復活してキャンプに留まります。出発すると戦闘を再開します。",
            .monsterShieldStatus: "シールド %.0f/%.0f",
            .monsterShieldDetails: "ダメージは敵の HP より先にシールドを減らします。新しいゴーレムはそれぞれ独立したシールドを持ちます。",
            .monsterRegenerationStatus: "待機時回復・毎秒 HP +%.1f%%",
            .monsterRegenerationPausedStatus: "回復停止中・毎秒 HP %.1f%%",
            .monsterRegenerationDetails: "Token 活動が 15 秒間ないと、生存中のスライムが最大 HP のこの割合を毎秒回復します。Token 活動やキャンプで回復が停止します。",
            .bossPhase1Status: "フェーズ 1",
            .bossPhase2Status: "フェーズ 2・攻撃 +%d%%",
            .bossPhaseDetails: "HP 50% でボスはフェーズ 2 に入り、与えるダメージが 50% 増加します。倒されるまでこの状態が続きます。",
            .shieldAbsorbed: "シールドが %.0f 吸収",
            .roleStatsShort: "攻撃 %+d%%\n待機被害 %+d%%",
            .roleChoiceAccessibility: "%@。%@。%@",
            .equipmentGoldBalance: "ゴールド %@",
            .equipmentBoostActive: "パワーブースト：ダメージ +%d%%・残り %d 秒",
            .equipmentBoostInactive: "一時的なダメージ強化はありません。",
            .equipmentRules: "高品質のドロップは自動装備され、同じか低い品質はゴールドになります。強化は現在の装備を 1 段階上げ、すぐに反映されます。",
            .equipmentRecentRewards: "最近の報酬・最新 40 件",
            .equipmentHistoryEmpty: "戦闘報酬と購入した強化がここに表示されます。",
            .equipmentCurrentState: "現在：%@・%@",
            .equipmentNextState: "次：%@・%@",
            .equipmentSlotEmpty: "未装備",
            .equipmentEmptyReason: "この部位の装備を戦闘で入手すると強化できます。",
            .equipmentMaxedReason: "最高品質に達しています。",
            .equipmentInsufficientGold: "あと %@ ゴールド必要です。",
            .equipmentUpgradeAction: "強化",
            .equipmentUpgradePrice: "強化・%@ G",
            .equipmentUpgradeAccessibility: "%@を%@に強化、%@ ゴールド",
            .equipmentUnavailableAccessibility: "%@：%@",
            .equipmentDetailedWeapon: "ダメージ +%d%%",
            .equipmentDetailedArmor: "待機時の被ダメージ −%d%%",
            .equipmentDetailedCharm: "スキルエネルギー獲得 +%d%%",
            .equipmentHistoryPotion: "ポーション・HP +%@",
            .equipmentHistoryBoost: "パワーブースト・+%d 秒",
            .equipmentHistoryGold: "ゴールド・+%d G",
            .equipmentHistoryBossGold: "ボス報酬・+%d G",
            .equipmentHistoryUpgrade: "%@に強化・−%d G",
            .lootPotionExactSummary: "ポーション HP +%@",
            .lootPotionExactFloat: "HP +%@",
            .stageTag: "ステージ %d",
            .stageTagBoss: "ステージ %d · BOSS",
            .stageReached: "ステージ %d に到達",
            .bossAppears: "BOSS %@ 出現！",
            .bossMonsterName: "BOSS %@",
            .comboText: "コンボ x%d",
            .critLabel: "会心",
            .levelUpBanner: "レベルアップ！",

            .backdrop: "背景シーン",
            .backdropMidnightForest: "深夜の森",
            .backdropCrystalCave: "クリスタル洞窟",
            .backdropSunsetDunes: "夕陽の砂丘",
            .backdropNeonCity: "ネオンシティ",

            // MARK: - スキルツリー
            .skillTreeAttack: "攻撃",
            .skillTreeDefense: "防御",
            .skillTreeEconomy: "経済",
            .skillTreeAbility: "スキル",
            .availableSkillPoints: "使用可能ポイント: %d",
            .selectNodePrompt: "ノードを選択",
            .currentLevel: "レベル: %d/%d",
            .requiresHeroLevel: "英雄レベル %d 必要",
            .requiresParent: "%@ 必要",
            .nodeUpgrade: "強化（1pt）",
            .nodeDowngrade: "1pt 返還",
            .nodeMaxed: "最大レベル",

            // 攻撃ノード
            .nodeAttackPower1: "強打 I",
            .nodeAttackPower1Desc: "Token 攻撃とアクティブスキルのダメージが上昇。",
            .nodeAttackPower2: "強打 II",
            .nodeAttackPower2Desc: "さらに攻撃力が上昇",
            .nodeCritChance1: "致命の目",
            .nodeCritChance1Desc: "クリティカル率が上昇",
            .nodeAttackSpeed1: "攻勢チャージ",
            .nodeAttackSpeed1Desc: "確認済み Token ごとのスキルエネルギー獲得量が増加。",
            .nodeAttackMastery: "攻撃の極意",
            .nodeAttackMasteryDesc: "攻撃力が大幅に上昇",
            .nodeBerserk: "バーサーク",
            .nodeBerserkDesc: "攻撃力が劇的に上昇",

            // 防御ノード
            .nodeHPBonus1: "生命力 I",
            .nodeHPBonus1Desc: "最大 HP が上昇。",
            .nodeHPBonus2: "生命力 II",
            .nodeHPBonus2Desc: "さらに最大 HP が上昇",
            .nodeArmor1: "鉄の皮膚",
            .nodeArmor1Desc: "被ダメージを軽減",
            .nodeHPRegen1: "再生",
            .nodeHPRegen1Desc: "生存中、毎秒固定量の HP を回復。",
            .nodeVitality: "生命の力",
            .nodeVitalityDesc: "最大 HP が大幅に上昇",
            .nodeImmortal: "不死",
            .nodeImmortalDesc: "被ダメージを大幅に軽減",

            // 経済ノード
            .nodeGoldBonus1: "金狩り I",
            .nodeGoldBonus1Desc: "ゴールド獲得が 10% 上昇",
            .nodeGoldBonus2: "金狩り II",
            .nodeGoldBonus2Desc: "さらにゴールド獲得が上昇",
            .nodeLootChance1: "幸運な発見",
            .nodeLootChance1Desc: "通常は何も落ちない場合に、一定確率で報酬を獲得。",
            .nodeXPBonus1: "知恵",
            .nodeXPBonus1Desc: "経験値獲得が上昇",
            .nodeMidas: "ミダスの手",
            .nodeMidasDesc: "ゴールド獲得が大幅に上昇",
            .nodeJackpot: "大当たり",
            .nodeJackpotDesc: "報酬なしを補う確率が大幅に上昇。",

            // スキルノード
            .nodeCooldownReduction1: "迅速詠唱 I",
            .nodeCooldownReduction1Desc: "スキルクールダウン短縮",
            .nodeCooldownReduction2: "迅速詠唱 II",
            .nodeCooldownReduction2Desc: "さらにクールダウン短縮",
            .nodeSkillPower1: "強化",
            .nodeSkillPower1Desc: "スキルダメージが上昇",
            .nodeEnergyRegen1: "エネルギー流動",
            .nodeEnergyRegen1Desc: "確認済み Token 消費によるエネルギー獲得量を増加。",
            .nodeAbilityMastery: "スキルの極意",
            .nodeAbilityMasteryDesc: "スキル威力が大幅に上昇",
            .nodeArcanePower: "神秘の力",
            .nodeArcanePowerDesc: "クールダウンが大幅に短縮",

            // 効果説明
            .effectDamageMultiplier: "ダメージ",
            .effectCritChance: "クリ率",
            .effectAttackSpeed: "攻勢チャージ",
            .effectMaxHP: "最大 HP",
            .effectDamageReduction: "ダメージ軽減",
            .effectHPRegen: "HP 回復",
            .effectGoldMultiplier: "ゴールド獲得",
            .effectLootChance: "報酬なしの補填確率",
            .effectXPMultiplier: "経験値獲得",
            .effectCooldownReduction: "クールダウン",
            .effectSkillDamage: "スキルダメージ",
            .effectEnergyRegen: "Token エネルギー獲得",

            // 設定タブ
            .tabGeneral: "一般",
            .tabGame: "ゲーム",
            .tabEquipment: "装備",
            .tabTools: "ツール",
            .tabSessions: "セッション",

            // セッション監視
            .activeSessions: "アクティブ IDE セッション",
            .noActiveSessions: "アクティブなセッションなし",
            .sessionCount: "%d セッション",
            .moreSessions: "他 %d 件",
            .sessionActive: "● アクティブ",
            .sessionIdle: "○ 待機中",
            .sessionUnknownProject: "不明なプロジェクト",
            .sessionUnknownTokenCount: "—",
            .sessionUnknownTokenUsage: "確認済みの Token 使用量がありません",
            .showSessions: "セッションを表示",
            .showBattle: "バトルを表示",
            .skillPassiveTree: "パッシブツリー",
            .skillActiveSkills: "アクティブスキル",
            .skillSharedBudget: "アクティブとパッシブで英雄レベルごとに 1 ポイントを共有します。各ランクは 1 ポイントで、返還は無料です。",
            .skillMigrationMessage: "以前のスキルランクを保持し、割り当て済みポイントのために %d ポイントを補填しました。各ランクは共有予算へ返還できます。",
            .skillMigrationAcknowledged: "確認",
            .skillRefundBlocked: "先に %@ を返還してください。この前提ランクが必要です。",
            .skillNoPoints: "ポイントがありません。レベルアップするか、他のランクを返還してください。",
            .skillRefundAvailable: "返還すると共有予算に 1 ポイント戻ります。",
            .skillPercentBonus: "+%.1f%%",
            .skillPercentReduction: "−%.1f%%",
            .skillHPPerSecond: "毎秒 %.2f HP",
            .skillCurrentEffect: "現在：%@",
            .skillNextEffect: "次：%@",
            .skillActiveCurrent: "現在：パッシブダメージ +%.1f%%・発動基礎ダメージ %@",
            .skillActiveNext: "次：パッシブダメージ +%.1f%%・発動基礎ダメージ %@",
            .skillCastDetails: "エネルギー %@・クールダウン %.1f 秒",
            .autoCastPriorityDetail: "使用可能な最上位スキルのためにエネルギーを蓄え、クールダウン中は他の有効スキルを発動します。確認済み Token 消費で充填し、ダメージとスキル補正が適用されます。",
            .skillEnergyStatus: "エネルギー %@ / %@・%@"
        ]
    ]
}
