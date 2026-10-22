import AppKit

struct MonsterEncounter: Equatable {
    let kind: MonsterKind
    let stage: Int
    let isBoss: Bool

    var maxHP: Int {
        StageProgress.maxHP(stage: stage, monster: kind, isBoss: isBoss)
    }
}
