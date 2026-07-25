import Foundation

extension Notification.Name {
    static let notchHeroLanguageChanged = Notification.Name("NotchHero.languageChanged")
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    private static let defaultsKey = "NotchHero.language"

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
    case showNotch
    case quitNotchHero
    case settingsTitle
    case language
    case heroRole
    case display
    case skills
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
            .showNotch: "Show Notch",
            .quitNotchHero: "Quit Vibe Hero",
            .settingsTitle: "Vibe Hero Settings",
            .language: "Language",
            .heroRole: "Hero Role",
            .display: "Display",
            .skills: "Skills",
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
            .hpPercent: "HP %d/100 (%d%%)",
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
            .skillPulseBladeSummary: "Sharper strikes and brighter slashes.",
            .skillTokenVolleySummary: "Fires extra token shards during active usage.",
            .skillArcBurstSummary: "Adds chained impact arcs around the target.",
            .skillWraithMarkSummary: "Marks the target for stronger burst damage.",
            .skillNovaStormSummary: "Adds high-tier storm rings and burst waves.",
            .skillOverclockCoreSummary: "Turns sustained usage into rapid mixed attacks.",
            .skillPulseBladeEffect: "+5% strike damage per rank",
            .skillTokenVolleyEffect: "+1 projectile per rank",
            .skillArcBurstEffect: "+1 chain arc per rank",
            .skillWraithMarkEffect: "+6% burst damage per rank",
            .skillNovaStormEffect: "Unlocks nova waves and orbit sparks",
            .skillOverclockCoreEffect: "Faster sustained attacks and larger impacts",

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
            .backdropNeonCity: "Neon City"
        ],
        .simplifiedChinese: [
            .showNotch: "显示刘海",
            .quitNotchHero: "退出 Vibe Hero",
            .settingsTitle: "Vibe Hero 设置",
            .language: "语言",
            .heroRole: "英雄角色",
            .display: "显示器",
            .skills: "技能",
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
            .hpPercent: "HP %d/100 (%d%%)",
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
            .skillPulseBladeSummary: "更锋利的斩击和更明亮的刀光。",
            .skillTokenVolleySummary: "活跃消耗时发射额外 token 碎片。",
            .skillArcBurstSummary: "在目标周围追加链式冲击电弧。",
            .skillWraithMarkSummary: "标记目标，提高爆发伤害。",
            .skillNovaStormSummary: "追加高阶风暴环和爆发波。",
            .skillOverclockCoreSummary: "将持续消耗转化为高速混合攻击。",
            .skillPulseBladeEffect: "每级 +5% 打击伤害",
            .skillTokenVolleyEffect: "每级 +1 个投射物",
            .skillArcBurstEffect: "每级 +1 条链式电弧",
            .skillWraithMarkEffect: "每级 +6% 爆发伤害",
            .skillNovaStormEffect: "解锁新星波和轨道火花",
            .skillOverclockCoreEffect: "持续攻击更快，冲击范围更大",

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
            .backdropNeonCity: "霓虹都市"
        ],
        .japanese: [
            .showNotch: "ノッチを表示",
            .quitNotchHero: "Vibe Hero を終了",
            .settingsTitle: "Vibe Hero 設定",
            .language: "言語",
            .heroRole: "ヒーロー役割",
            .display: "ディスプレイ",
            .skills: "スキル",
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
            .hpPercent: "HP %d/100 (%d%%)",
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
            .skillPulseBladeSummary: "鋭い斬撃と明るいスラッシュ。",
            .skillTokenVolleySummary: "使用中に追加の token シャードを発射。",
            .skillArcBurstSummary: "対象周辺に連鎖インパクトアークを追加。",
            .skillWraithMarkSummary: "対象をマークし、バーストダメージを強化。",
            .skillNovaStormSummary: "高ティアのストームリングとバースト波を追加。",
            .skillOverclockCoreSummary: "継続使用を高速な混合攻撃へ変換。",
            .skillPulseBladeEffect: "ランクごとに打撃ダメージ +5%",
            .skillTokenVolleyEffect: "ランクごとに投射物 +1",
            .skillArcBurstEffect: "ランクごとにチェインアーク +1",
            .skillWraithMarkEffect: "ランクごとにバーストダメージ +6%",
            .skillNovaStormEffect: "ノヴァ波と軌道スパークを解放",
            .skillOverclockCoreEffect: "継続攻撃が高速化し、衝撃が拡大",

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
            .backdropNeonCity: "ネオンシティ"
        ]
    ]
}
