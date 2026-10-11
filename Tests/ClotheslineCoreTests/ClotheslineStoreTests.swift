import XCTest
@testable import ClotheslineCore

final class ClotheslineStoreTests: TempDirTestCase {
    var clock = Date(timeIntervalSince1970: 1_800_000_000)

    func makeStore() -> ClotheslineStore {
        ClotheslineStore(root: tmp.appendingPathComponent("Root")) { [unowned self] in self.clock }
    }

    func testImageIsMovedIn() throws {
        let store = makeStore()
        let src = try makeFile("Downloads/photo.jpg")
        let item = try store.add(src)
        XCTAssertEqual(item.kind, .image)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(item.path.hasPrefix(store.imagesDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }

    func testFileIsReferenced() throws {
        let store = makeStore()
        let src = try makeFile("Docs/report.pdf")
        let item = try store.add(src)
        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.path, src.standardizedFileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path))
    }

    func testFolderIsReferenced() throws {
        let store = makeStore()
        let dir = try makeDir("Project.images.png")
        XCTAssertEqual(try store.add(dir).kind, .file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }

    func testNewestFirstAndReaddMovesToTop() throws {
        let store = makeStore()
        let a = try store.add(try makeFile("a.pdf"))
        let b = try store.add(try makeFile("b.txt"))
        XCTAssertEqual(store.items.map(\.id), [b.id, a.id])
        try store.add(a.url)
        XCTAssertEqual(store.items.map(\.path), [a.path, b.path])
    }

    func testNameCollisionsGetSuffix() throws {
        let store = makeStore()
        let first = try store.add(try makeFile("one/shot.png"))
        let second = try store.add(try makeFile("two/shot.png"))
        XCTAssertNotEqual(first.path, second.path)
        XCTAssertEqual(second.url.lastPathComponent, "shot 2.png")
    }

    func testPersistsAcrossRestart() throws {
        let store = makeStore()
        try store.add(try makeFile("a.png"))
        try store.add(try makeFile("b.pdf"))
        XCTAssertEqual(makeStore().items.map(\.path), store.items.map(\.path))
    }

    func testMissingDetection() throws {
        let store = makeStore()
        let src = try makeFile("gone.pdf")
        let item = try store.add(src)
        XCTAssertFalse(item.isMissing)
        try FileManager.default.removeItem(at: src)
        XCTAssertTrue(item.isMissing)
    }

    func testOnChangeFires() throws {
        let store = makeStore()
        var count = 0
        store.onChange = { count += 1 }
        let item = try store.add(try makeFile("a.pdf"))
        store.remove(item.id)
        XCTAssertEqual(count, 2)
    }

    func testRemovingFileLeavesOriginal() throws {
        let store = makeStore()
        let src = try makeFile("keep.pdf")
        store.remove(try store.add(src).id, trashing: true)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path))
    }

    func testRetiredPhotoStaysUntil24Hours() throws {
        let store = makeStore()
        let item = try store.add(try makeFile("p.png"))
        store.remove(item.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))

        clock += 23 * 3600
        store.cleanUpRetired()
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))

        clock += 2 * 3600
        store.cleanUpRetired()
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
    }

    func testRetiredCleanupSurvivesRestart() throws {
        let item = try makeStore().add(try makeFile("p.png"))
        makeStore().remove(item.id)
        clock += 25 * 3600
        makeStore().cleanUpRetired()
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
    }

    func testCleanupNeverDeletesHangingPhoto() throws {
        let store = makeStore()
        let item = try store.add(try makeFile("p.png"))
        store.remove(item.id)
        try store.add(item.url) // 又挂回去了
        clock += 48 * 3600
        store.cleanUpRetired()
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
        XCTAssertEqual(store.items.count, 1)
    }
}
