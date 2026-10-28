import Foundation
@testable import Ora
import Testing

struct TabReorderingTests {
    private let ids = (0 ..< 4).map { _ in UUID() }

    @Test func movingDownLandsAfterTheTarget() {
        let result = TabReordering.reordered(ids, moving: ids[0], onto: ids[2])
        #expect(result == [ids[1], ids[2], ids[0], ids[3]])
    }

    @Test func movingUpLandsBeforeTheTarget() {
        let result = TabReordering.reordered(ids, moving: ids[3], onto: ids[1])
        #expect(result == [ids[0], ids[3], ids[1], ids[2]])
    }

    @Test func movingOntoTheNextTabSwapsThem() {
        let result = TabReordering.reordered(ids, moving: ids[1], onto: ids[2])
        #expect(result == [ids[0], ids[2], ids[1], ids[3]])
    }

    @Test func movingOntoTheLastTabPutsItLast() {
        let result = TabReordering.reordered(ids, moving: ids[0], onto: ids[3])
        #expect(result == [ids[1], ids[2], ids[3], ids[0]])
    }

    @Test func aTabFromAnotherSectionTakesTheTargetsPlace() {
        let newcomer = UUID()
        let result = TabReordering.reordered(ids, moving: newcomer, onto: ids[1])
        #expect(result == [ids[0], newcomer, ids[1], ids[2], ids[3]])
    }

    @Test func movingOntoItselfOrAnUnknownTargetChangesNothing() {
        #expect(TabReordering.reordered(ids, moving: ids[1], onto: ids[1]) == ids)
        #expect(TabReordering.reordered(ids, moving: ids[1], onto: UUID()) == ids)
    }

    @Test func everyTabIsKeptExactlyOnce() {
        let result = TabReordering.reordered(ids, moving: ids[2], onto: ids[0])
        #expect(result.count == ids.count)
        #expect(Set(result) == Set(ids))
    }

    @Test func aDuplicateIsInsertedRightAfterItsOriginal() {
        let duplicate = UUID()
        let result = TabReordering.inserted(ids, inserting: duplicate, after: ids[1])
        #expect(result == [ids[0], ids[1], duplicate, ids[2], ids[3]])
    }

    @Test func aDuplicateAlreadyListedMovesRightAfterItsOriginal() {
        let result = TabReordering.inserted(ids, inserting: ids[0], after: ids[2])
        #expect(result == [ids[1], ids[2], ids[0], ids[3]])
    }

    @Test func aDuplicateOfTheLastTabGoesLast() {
        let duplicate = UUID()
        let result = TabReordering.inserted(ids, inserting: duplicate, after: ids[3])
        #expect(result.last == duplicate)
    }
}
