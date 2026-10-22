import AppKit

/// Persisted lifetime kill count. Stage, boss cadence and scaling are all
/// derived from this single number, so they survive relaunches without any
/// separate flags to keep in sync.
enum StageTracker {
    static func loadTotalKills() -> Int {
        max(0, Defaults.int(forKey: DefaultsKey.totalKills))
    }

    static func saveTotalKills(_ kills: Int) {
        Defaults.set(max(0, kills), forKey: DefaultsKey.totalKills)
    }
}

enum StageProgress {
    static let killsPerStage = 8
    static let bossStageInterval = 5

    static func stage(for totalKills: Int) -> Int {
        max(0, totalKills) / killsPerStage + 1
    }

    static func isBossStage(_ stage: Int) -> Bool {
        stage > 0 && stage % bossStageInterval == 0
    }

    static func killsIntoStage(for totalKills: Int) -> Int {
        max(0, totalKills) % killsPerStage
    }

    // A boss is the first encounter of every boss stage. Deriving this from the
    // persisted kill count makes it survive relaunches without separate flags.
    static func isBossEncounter(totalKills: Int) -> Bool {
        let stage = stage(for: totalKills)
        return isBossStage(stage) && killsIntoStage(for: totalKills) == 0
    }

    /// Boss identity derives from its ordinal, independently of the regular
    /// four-enemy cycle (five stages contain forty kills, a multiple of four).
    static func bossKind(stage: Int) -> MonsterKind {
        let ordinal = max(0, max(1, stage) / bossStageInterval - 1)
        return MonsterKind.allCases[ordinal % MonsterKind.allCases.count]
    }

    // Absolute HP pool: the monster's stat scaled into token-sized units, then
    // deepened by stage and boss factors. These factors used to divide incoming
    // damage instead — same overall pace, but folded into max HP so the bar
    // always moves visibly.
    static func maxHP(stage: Int, monster: MonsterKind, isBoss: Bool) -> Int {
        let stageFactor = 1 + 0.10 * CGFloat(max(1, stage) - 1)
        let bossFactor: CGFloat = isBoss ? 2.2 : 1
        return max(1, Int((CGFloat(monster.maxHP) * 100 * stageFactor * bossFactor).rounded()))
    }

    static func xpMultiplier(stage: Int, isBoss: Bool) -> CGFloat {
        let stageFactor = 1 + 0.08 * CGFloat(max(1, stage) - 1)
        return stageFactor * (isBoss ? 2 : 1)
    }
}

struct MonsterBatchPlan: Equatable {
    let encounters: [MonsterEncounter]
    let nextKind: MonsterKind
}

/// Builds the queue of monsters that walk in from off-screen. A batch never
/// crosses a stage boundary, and a boss always arrives alone.
enum MonsterEncounterPlanner {
    static func makeBatch(
        totalKills: Int,
        startingKind: MonsterKind,
        requestedCount: Int
    ) -> MonsterBatchPlan {
        let completedKills = max(0, totalKills)
        let stage = StageProgress.stage(for: completedKills)
        let killsIntoStage = StageProgress.killsIntoStage(for: completedKills)
        let remainingInStage = StageProgress.killsPerStage - killsIntoStage
        let count = StageProgress.isBossEncounter(totalKills: completedKills)
            ? 1
            : min(max(1, requestedCount), remainingInStage)

        var nextKind = startingKind
        var encounters: [MonsterEncounter] = []
        encounters.reserveCapacity(count)

        for offset in 0..<count {
            let encounterKills = completedKills + offset
            encounters.append(
                MonsterEncounter(
                    kind: StageProgress.isBossEncounter(totalKills: encounterKills)
                        ? StageProgress.bossKind(stage: stage) : nextKind,
                    stage: stage,
                    isBoss: StageProgress.isBossEncounter(totalKills: encounterKills)
                )
            )
            nextKind = nextKind.next
        }

        return MonsterBatchPlan(encounters: encounters, nextKind: nextKind)
    }
}
