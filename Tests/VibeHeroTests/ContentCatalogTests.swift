import AppKit
import XCTest
@testable import VibeHero

/// The content catalogs replaced exhaustive `switch` statements, which the
/// compiler used to check for completeness. These tests restore that guarantee:
/// a new enum case with no catalog entry fails here instead of silently falling
/// back at runtime.
final class ContentCatalogTests: XCTestCase {
    func testEveryMonsterHasASpec() {
        for kind in MonsterKind.allCases {
            XCTAssertNotNil(MonsterCatalog.all[kind], "MonsterCatalog is missing \(kind)")
        }
        XCTAssertEqual(MonsterCatalog.all.count, MonsterKind.allCases.count)
    }

    func testEveryBackdropHasASpec() {
        for backdrop in BattleBackdrop.allCases {
            XCTAssertNotNil(BackdropCatalog.all[backdrop], "BackdropCatalog is missing \(backdrop)")
        }
        XCTAssertEqual(BackdropCatalog.all.count, BattleBackdrop.allCases.count)
    }

    func testEveryRoleHasASpec() {
        for role in HeroRole.allCases {
            XCTAssertNotNil(RoleCatalog.all[role], "RoleCatalog is missing \(role)")
        }
        XCTAssertEqual(RoleCatalog.all.count, HeroRole.allCases.count)
    }

    func testEverySkillHasASpec() {
        for skill in HeroSkill.allCases {
            XCTAssertNotNil(SkillCatalog.all[skill], "SkillCatalog is missing \(skill)")
        }
        XCTAssertEqual(SkillCatalog.all.count, HeroSkill.allCases.count)
    }

    func testMonsterStatsSurviveTheMoveIntoTheCatalog() {
        XCTAssertEqual(MonsterKind.promptWraith.maxHP, 120)
        XCTAssertEqual(MonsterKind.cacheGolem.maxHP, 170)
        XCTAssertEqual(MonsterKind.tokenSlime.maxHP, 95)
        XCTAssertEqual(MonsterKind.nullSentinel.maxHP, 145)

        XCTAssertEqual(MonsterKind.promptWraith.xpReward, 45)
        XCTAssertEqual(MonsterKind.cacheGolem.xpReward, 65)
        XCTAssertEqual(MonsterKind.tokenSlime.xpReward, 35)
        XCTAssertEqual(MonsterKind.nullSentinel.xpReward, 55)
    }

    func testRoleMultipliersSurviveTheMoveIntoTheCatalog() {
        XCTAssertEqual(HeroRole.engineer.damageMultiplier, 1.15)
        XCTAssertEqual(HeroRole.pm.damageMultiplier, 1.04)
        XCTAssertEqual(HeroRole.designer.damageMultiplier, 1.0)

        XCTAssertEqual(HeroRole.qa.idleDamageMultiplier, 0.75)
        XCTAssertEqual(HeroRole.artist.idleDamageMultiplier, 0.82)
        XCTAssertEqual(HeroRole.pm.idleDamageMultiplier, 0.92)
        XCTAssertEqual(HeroRole.engineer.idleDamageMultiplier, 1.0)
    }

    func testMonsterRotationVisitsEveryKindBeforeRepeating() {
        var kind = MonsterKind.promptWraith
        var seen: [MonsterKind] = [kind]
        for _ in 1..<MonsterKind.allCases.count {
            kind = kind.next
            seen.append(kind)
        }

        XCTAssertEqual(Set(seen).count, MonsterKind.allCases.count)
        XCTAssertEqual(kind.next, .promptWraith)
    }

    func testMonsterSpritesAreNonEmptyAndInsideTheGrid() {
        for kind in MonsterKind.allCases {
            let sprite = kind.spec.sprite
            XCTAssertFalse(sprite.isEmpty, "\(kind) has no sprite cells")
            for cell in sprite {
                XCTAssertGreaterThanOrEqual(cell.x, 0, "\(kind) cell starts left of the grid")
                XCTAssertGreaterThanOrEqual(cell.y, 0, "\(kind) cell starts above the grid")
                XCTAssertLessThanOrEqual(cell.x + cell.w, 16, "\(kind) cell overflows the grid width")
                XCTAssertLessThanOrEqual(cell.y + cell.h, 16, "\(kind) cell overflows the grid height")
            }
        }
    }

    func testEveryRoleDrawsABodyPlusItsOwnAccessory() {
        for role in HeroRole.allCases {
            let body = PixelSprites.heroBody(palette: role.spec.palette)
            XCTAssertEqual(body.count, 10, "hero body changed shape for \(role)")
            XCTAssertFalse(role.spec.accessory.isEmpty, "\(role) has no accessory")
        }
    }

    /// Prerequisites are declared per skill; a cycle or a forward reference would
    /// make a skill permanently unreachable.
    func testSkillPrerequisitesPointAtLowerTiers() {
        for skill in HeroSkill.allCases {
            for prerequisite in skill.prerequisites {
                XCTAssertLessThan(
                    prerequisite.skill.treeTier,
                    skill.treeTier,
                    "\(skill) requires \(prerequisite.skill), which is not below it in the tree"
                )
                XCTAssertLessThanOrEqual(
                    prerequisite.rank,
                    prerequisite.skill.maxRank,
                    "\(skill) requires more ranks of \(prerequisite.skill) than it can have"
                )
            }
        }
    }
}
