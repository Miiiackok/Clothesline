import XCTest
@testable import ClotheslineCore

final class ScreenshotDetectorTests: TempDirTestCase {
    func testScreenshotNames() throws {
        for name in ["Screenshot 2026-10-11 at 10.33.12.png", "Screen Shot 2020-01-01 at 1.00.00 PM.png",
                     "截屏2026-10-11 10.33.12.png", "屏幕快照 2019-01-01 上午10.00.00.png"] {
            XCTAssertTrue(ScreenshotDetector.isScreenshot(try makeFile(name)), name)
        }
    }

    func testScreenCaptureAttribute() throws {
        let url = try makeFile("custom-name.png")
        XCTAssertFalse(ScreenshotDetector.isScreenshot(url))
        let value = Data("1".utf8)
        _ = value.withUnsafeBytes {
            setxattr(url.path, ScreenshotDetector.screenCaptureAttribute, $0.baseAddress, value.count, 0, 0)
        }
        XCTAssertTrue(ScreenshotDetector.isScreenshot(url))
    }

    func testExcludesHiddenAndNonImages() throws {
        XCTAssertFalse(ScreenshotDetector.isScreenshot(try makeFile(".Screenshot 2026.png")))
        XCTAssertFalse(ScreenshotDetector.isScreenshot(try makeFile("Screenshot notes.txt")))
        XCTAssertFalse(ScreenshotDetector.isScreenshot(try makeFile("holiday.jpg")))
    }

    func testScreenshotDirectory() throws {
        let defaults = UserDefaults(suiteName: "ClotheslineTests-\(UUID().uuidString)")!
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        XCTAssertEqual(ScreenshotDetector.screenshotDirectory(defaults: defaults), desktop)
        defaults.set(tmp.path, forKey: "location")
        XCTAssertEqual(ScreenshotDetector.screenshotDirectory(defaults: defaults).path, tmp.path)
        defaults.set("/no/such/dir", forKey: "location")
        XCTAssertEqual(ScreenshotDetector.screenshotDirectory(defaults: defaults), desktop)
    }
}

final class ScreenshotWatcherTests: TempDirTestCase {
    func testReportsNewScreenshotsOnce() throws {
        try makeFile("Screenshot old.png")
        var reported: [String] = []
        let watcher = try ScreenshotWatcher(directory: tmp) { reported.append($0.lastPathComponent) }
        try makeFile("holiday.jpg")
        try makeFile("Screenshot new.png")
        spin(0.6)
        watcher.scan()
        watcher.scan()
        XCTAssertEqual(reported, ["Screenshot new.png"])
    }
}

final class DirectoryMonitorTests: TempDirTestCase {
    func testSafeSaveIsSeenAndCoalesced() throws {
        let target = try makeFile("photo.png")
        var calls = 0
        let monitor = try DirectoryMonitor(url: tmp, debounce: 0.2) { calls += 1 }
        // 「预览」式保存：写临时文件再替换
        let temp = try makeFile(".photo.png.sb-tmp", contents: "edited")
        _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
        try makeFile("another.png")
        spin(0.6)
        XCTAssertEqual(calls, 1)
        _ = monitor
    }

    func testMissingDirectoryThrows() {
        XCTAssertThrowsError(try DirectoryMonitor(url: tmp.appendingPathComponent("nope")) {})
    }
}

final class FileBadgeTests: TempDirTestCase {
    func badge(_ name: String) -> FileBadge { FileBadge.badge(for: tmp.appendingPathComponent(name)) }

    func testKnownTypes() {
        XCTAssertEqual(badge("a.pdf"), FileBadge(text: "PDF", tint: .red))
        XCTAssertEqual(badge("a.docx"), FileBadge(text: "DOC", tint: .blue))
        XCTAssertEqual(badge("a.numbers"), FileBadge(text: "NUMBERS", tint: .green))
        XCTAssertEqual(badge("a.key"), FileBadge(text: "KEY", tint: .orange))
        XCTAssertEqual(badge("a.7z"), FileBadge(text: "7Z", tint: .purple))
        XCTAssertEqual(badge("a.MP3"), FileBadge(text: "MP3", tint: .pink))
        XCTAssertEqual(badge("a.mov"), FileBadge(text: "MOV", tint: .indigo))
        XCTAssertEqual(badge("a.md"), FileBadge(text: "MD", tint: .brown))
    }

    func testFolderUnknownAndNoExtension() throws {
        XCTAssertEqual(FileBadge.badge(for: try makeDir("Stuff")), FileBadge(text: "文件夹", tint: .teal))
        XCTAssertEqual(badge("a.sketchbook"), FileBadge(text: "SKETC", tint: .darkBrown))
        XCTAssertEqual(badge("Makefile"), FileBadge(text: "FILE", tint: .darkBrown))
    }
}
