import Foundation

extension Notification.Name {
    static let notchHeroLanguageChanged = Notification.Name("VibeHero.languageChanged")
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    private static let defaultsKey = "VibeHero.language"

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .japanese: "日本語"
        }
    }

    static func load() -> AppLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
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
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
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
    case hookKimiDetail
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
}

enum L10n {
    static func text(_ key: L10nKey) -> String {
        let language = AppLanguage.load()
        return translations[language]?[key] ?? translations[.english]?[key] ?? key.rawValue
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
            .tokenHooks: "Token Hooks",
            .tokenHooksDetail: "Install hooks to capture token events faster and fall back when local logs are delayed.",
            .installHook: "Install",
            .hookInstalled: "Installed",
            .hookInstallFailed: "Install failed: %@",
            .hookInstalledDetail: "Hook installed. Restart or reopen the tool if it is already running.",
            .hookClaudeDetail: "Adds Claude Code hooks to ~/.claude/settings.json.",
            .hookCodexDetail: "Adds Codex hooks to ~/.codex/hooks.json.",
            .hookOpenCodeDetail: "Adds an OpenCode plugin to ~/.config/opencode/plugins.",
            .hookKimiDetail: "Adds an MCP server to ~/.kimi-code/config.toml for token tracking.",
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
            .skillReadyStatus: "Auto Cast ready (%@)",
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
            .nodeUpgrade: "Upgrade",
            .nodeDowngrade: "Downgrade",
            .nodeMaxed: "Maxed",

            // Attack nodes
            .nodeAttackPower1: "Power Strike I",
            .nodeAttackPower1Desc: "Increase attack damage by 5%",
            .nodeAttackPower2: "Power Strike II",
            .nodeAttackPower2Desc: "Further increase attack damage",
            .nodeCritChance1: "Critical Eye",
            .nodeCritChance1Desc: "Increase critical hit chance",
            .nodeAttackSpeed1: "Swift Strike",
            .nodeAttackSpeed1Desc: "Increase attack speed",
            .nodeAttackMastery: "Attack Mastery",
            .nodeAttackMasteryDesc: "Significantly boost attack power",
            .nodeBerserk: "Berserk",
            .nodeBerserkDesc: "Massive damage boost",

            // Defense nodes
            .nodeHPBonus1: "Vitality I",
            .nodeHPBonus1Desc: "Increase max HP by 10%",
            .nodeHPBonus2: "Vitality II",
            .nodeHPBonus2Desc: "Further increase max HP",
            .nodeArmor1: "Iron Skin",
            .nodeArmor1Desc: "Reduce damage taken",
            .nodeHPRegen1: "Regeneration",
            .nodeHPRegen1Desc: "Slowly regenerate HP",
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
            .nodeLootChance1Desc: "Increase loot drop chance",
            .nodeXPBonus1: "Wisdom",
            .nodeXPBonus1Desc: "Increase XP gain",
            .nodeMidas: "Midas Touch",
            .nodeMidasDesc: "Greatly increase gold gain",
            .nodeJackpot: "Jackpot",
            .nodeJackpotDesc: "Massive loot bonus",

            // Ability nodes
            .nodeCooldownReduction1: "Quick Cast I",
            .nodeCooldownReduction1Desc: "Reduce skill cooldown",
            .nodeCooldownReduction2: "Quick Cast II",
            .nodeCooldownReduction2Desc: "Further reduce cooldown",
            .nodeSkillPower1: "Empowered",
            .nodeSkillPower1Desc: "Increase skill damage",
            .nodeEnergyRegen1: "Energy Flow",
            .nodeEnergyRegen1Desc: "Faster energy regeneration",
            .nodeAbilityMastery: "Ability Mastery",
            .nodeAbilityMasteryDesc: "Greatly boost skill power",
            .nodeArcanePower: "Arcane Power",
            .nodeArcanePowerDesc: "Massive cooldown reduction",

            // Effect descriptions
            .effectDamageMultiplier: "Damage",
            .effectCritChance: "Crit Chance",
            .effectAttackSpeed: "Attack Speed",
            .effectMaxHP: "Max HP",
            .effectDamageReduction: "Damage Reduction",
            .effectHPRegen: "HP Regen",
            .effectGoldMultiplier: "Gold Gain",
            .effectLootChance: "Loot Chance",
            .effectXPMultiplier: "XP Gain",
            .effectCooldownReduction: "Cooldown",
            .effectSkillDamage: "Skill Damage",
            .effectEnergyRegen: "Energy Regen",

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
            .moreSessions: "+%d more"
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
            .tokenHooks: "Token Hooks",
            .tokenHooksDetail: "安装 hook 以更快捕获 token 事件，并在本地日志延迟时兜底。",
            .installHook: "安装",
            .hookInstalled: "已安装",
            .hookInstallFailed: "安装失败：%@",
            .hookInstalledDetail: "Hook 已安装。如果工具正在运行，请重启或重新打开它。",
            .hookClaudeDetail: "向 ~/.claude/settings.json 添加 Claude Code hooks。",
            .hookCodexDetail: "向 ~/.codex/hooks.json 添加 Codex hooks。",
            .hookOpenCodeDetail: "向 ~/.config/opencode/plugins 添加 OpenCode plugin。",
            .hookKimiDetail: "向 ~/.kimi-code/config.toml 添加 MCP 服务器以追踪 token 用量。",
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
            .skillReadyStatus: "自动释放已就绪（%@）",
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
            .nodeUpgrade: "升级",
            .nodeDowngrade: "降级",
            .nodeMaxed: "已满级",

            // 攻击节点
            .nodeAttackPower1: "强力打击 I",
            .nodeAttackPower1Desc: "攻击力提升 5%",
            .nodeAttackPower2: "强力打击 II",
            .nodeAttackPower2Desc: "进一步提升攻击力",
            .nodeCritChance1: "暴击之眼",
            .nodeCritChance1Desc: "提升暴击率",
            .nodeAttackSpeed1: "迅捷打击",
            .nodeAttackSpeed1Desc: "提升攻击速度",
            .nodeAttackMastery: "攻击精通",
            .nodeAttackMasteryDesc: "大幅提升攻击力",
            .nodeBerserk: "狂暴",
            .nodeBerserkDesc: "攻击力暴增",

            // 防御节点
            .nodeHPBonus1: "生命力 I",
            .nodeHPBonus1Desc: "最大生命值提升 10%",
            .nodeHPBonus2: "生命力 II",
            .nodeHPBonus2Desc: "进一步提升最大生命值",
            .nodeArmor1: "铁皮皮肤",
            .nodeArmor1Desc: "减少受到的伤害",
            .nodeHPRegen1: "生命恢复",
            .nodeHPRegen1Desc: "缓慢恢复生命值",
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
            .nodeLootChance1Desc: "提升战利品掉落率",
            .nodeXPBonus1: "智慧",
            .nodeXPBonus1Desc: "提升经验获取",
            .nodeMidas: "点金之手",
            .nodeMidasDesc: "大幅提升金币获取",
            .nodeJackpot: "头奖",
            .nodeJackpotDesc: "战利品暴增",

            // 技能节点
            .nodeCooldownReduction1: "快速施法 I",
            .nodeCooldownReduction1Desc: "减少技能冷却时间",
            .nodeCooldownReduction2: "快速施法 II",
            .nodeCooldownReduction2Desc: "进一步减少冷却时间",
            .nodeSkillPower1: "技能强化",
            .nodeSkillPower1Desc: "提升技能伤害",
            .nodeEnergyRegen1: "能量流动",
            .nodeEnergyRegen1Desc: "加快能量恢复",
            .nodeAbilityMastery: "技能精通",
            .nodeAbilityMasteryDesc: "大幅提升技能威力",
            .nodeArcanePower: "奥术之力",
            .nodeArcanePowerDesc: "大幅减少冷却时间",

            // 效果描述
            .effectDamageMultiplier: "伤害",
            .effectCritChance: "暴击率",
            .effectAttackSpeed: "攻击速度",
            .effectMaxHP: "最大生命",
            .effectDamageReduction: "伤害减免",
            .effectHPRegen: "生命恢复",
            .effectGoldMultiplier: "金币获取",
            .effectLootChance: "战利品几率",
            .effectXPMultiplier: "经验获取",
            .effectCooldownReduction: "冷却时间",
            .effectSkillDamage: "技能伤害",
            .effectEnergyRegen: "能量恢复",

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
            .moreSessions: "还有 %d 个"
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
            .tokenHooks: "Token Hooks",
            .tokenHooksDetail: "Hook を入れて token イベントをより速く取得し、ローカルログ遅延時の補完に使います。",
            .installHook: "インストール",
            .hookInstalled: "インストール済み",
            .hookInstallFailed: "インストール失敗：%@",
            .hookInstalledDetail: "Hook をインストールしました。ツールが起動中の場合は再起動してください。",
            .hookClaudeDetail: "~/.claude/settings.json に Claude Code hooks を追加します。",
            .hookCodexDetail: "~/.codex/hooks.json に Codex hooks を追加します。",
            .hookOpenCodeDetail: "~/.config/opencode/plugins に OpenCode plugin を追加します。",
            .hookKimiDetail: "~/.kimi-code/config.toml に MCP サーバーを追加して token 使用量を追跡します。",
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
            .skillReadyStatus: "自動発動準備完了（%@）",
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
            .nodeUpgrade: "アップグレード",
            .nodeDowngrade: "ダウングレード",
            .nodeMaxed: "最大レベル",

            // 攻撃ノード
            .nodeAttackPower1: "強打 I",
            .nodeAttackPower1Desc: "攻撃力が 5% 上昇",
            .nodeAttackPower2: "強打 II",
            .nodeAttackPower2Desc: "さらに攻撃力が上昇",
            .nodeCritChance1: "致命の目",
            .nodeCritChance1Desc: "クリティカル率が上昇",
            .nodeAttackSpeed1: "速撃",
            .nodeAttackSpeed1Desc: "攻撃速度が上昇",
            .nodeAttackMastery: "攻撃の極意",
            .nodeAttackMasteryDesc: "攻撃力が大幅に上昇",
            .nodeBerserk: "バーサーク",
            .nodeBerserkDesc: "攻撃力が劇的に上昇",

            // 防御ノード
            .nodeHPBonus1: "生命力 I",
            .nodeHPBonus1Desc: "最大 HP が 10% 上昇",
            .nodeHPBonus2: "生命力 II",
            .nodeHPBonus2Desc: "さらに最大 HP が上昇",
            .nodeArmor1: "鉄の皮膚",
            .nodeArmor1Desc: "被ダメージを軽減",
            .nodeHPRegen1: "再生",
            .nodeHPRegen1Desc: "HP が徐々に回復",
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
            .nodeLootChance1Desc: "戦利品ドロップ率が上昇",
            .nodeXPBonus1: "知恵",
            .nodeXPBonus1Desc: "経験値獲得が上昇",
            .nodeMidas: "ミダスの手",
            .nodeMidasDesc: "ゴールド獲得が大幅に上昇",
            .nodeJackpot: "大当たり",
            .nodeJackpotDesc: "戦利品が劇的に増加",

            // スキルノード
            .nodeCooldownReduction1: "迅速詠唱 I",
            .nodeCooldownReduction1Desc: "スキルクールダウン短縮",
            .nodeCooldownReduction2: "迅速詠唱 II",
            .nodeCooldownReduction2Desc: "さらにクールダウン短縮",
            .nodeSkillPower1: "強化",
            .nodeSkillPower1Desc: "スキルダメージが上昇",
            .nodeEnergyRegen1: "エネルギー流動",
            .nodeEnergyRegen1Desc: "エネルギー回復が加速",
            .nodeAbilityMastery: "スキルの極意",
            .nodeAbilityMasteryDesc: "スキル威力が大幅に上昇",
            .nodeArcanePower: "神秘の力",
            .nodeArcanePowerDesc: "クールダウンが大幅に短縮",

            // 効果説明
            .effectDamageMultiplier: "ダメージ",
            .effectCritChance: "クリ率",
            .effectAttackSpeed: "攻撃速度",
            .effectMaxHP: "最大 HP",
            .effectDamageReduction: "ダメージ軽減",
            .effectHPRegen: "HP 回復",
            .effectGoldMultiplier: "ゴールド獲得",
            .effectLootChance: "戦利品率",
            .effectXPMultiplier: "経験値獲得",
            .effectCooldownReduction: "クールダウン",
            .effectSkillDamage: "スキルダメージ",
            .effectEnergyRegen: "エネルギー回復",

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
            .moreSessions: "他 %d 件"
        ]
    ]
}
