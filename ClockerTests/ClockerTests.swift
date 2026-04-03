import XCTest
@testable import Clocker
import AppUpdater

final class ClockerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClockerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testTimeWriterPersistsAndClearsTodayRecord() throws {
        let writer = TimeWriter(storageURL: tempDirectory)
        writer.persist("01:02")

        let fileURL = todayFileURL()
        writer.waitUntilIdle()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "01:02\n")

        writer.persist("01:03")
        writer.waitUntilIdle()
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "01:02\n01:03\n")

        writer.clearTodayRecord()
        writer.waitUntilIdle()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testTimeWriterPersistsAndClearsProjectRecord() throws {
        let writer = TimeWriter(storageURL: tempDirectory)
        writer.persist("00:15", projectID: "project-123")

        let fileURL = ClockModel.currentDayFileURL(storageURL: tempDirectory, projectID: "project-123")
        writer.waitUntilIdle()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "00:15\n")

        writer.clearTodayRecord(projectID: "project-123")
        writer.waitUntilIdle()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testHistoryRecordStatusStorePersistsAndClearsDoneState() throws {
        let store = HistoryRecordStatusStore()
        let fileURL = todayFileURL()
        let statusURL = HistoryRecordStatusStore.statusFileURL(for: fileURL)

        XCTAssertFalse(store.isDone(for: fileURL))

        store.setDone(true, for: fileURL)
        XCTAssertTrue(store.isDone(for: fileURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: statusURL.path))
        XCTAssertEqual(try String(contentsOf: statusURL, encoding: .utf8), "{\n  \"isDone\" : true\n}")

        store.setDone(false, for: fileURL)
        XCTAssertFalse(store.isDone(for: fileURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: statusURL.path))
    }

    func testClockModelParsesRestoredTimeFromLastNonEmptyLine() {
        XCTAssertEqual(ClockModel.parseElapsedSeconds(from: "00:01\n00:42\n"), 42)
        XCTAssertEqual(ClockModel.parseElapsedSeconds(from: "\n 01:02:03 \n\n"), 3723)
        XCTAssertNil(ClockModel.parseElapsedSeconds(from: ""))
        XCTAssertNil(ClockModel.parseElapsedSeconds(from: "bad\nvalue"))
    }

    func testClockModelFormatsElapsedTime() {
        XCTAssertEqual(ClockModel.formatElapsed(59), "00:59")
        XCTAssertEqual(ClockModel.formatElapsed(61), "01:01")
        XCTAssertEqual(ClockModel.formatElapsed(3661), "1:01:01")
    }

    func testHistoryDataBuilderBuildsFileEntriesInFilesMode() throws {
        let fileURL = try createHistoryFile(name: "2026-01-01.txt", contents: "00:00:59\n")

        let result = HistoryDataBuilder.makeResult(
            for: [fileURL],
            mode: .files,
            isDone: { _ in true }
        )

        XCTAssertNil(result.summaryText)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].title, "2026-01-01.txt")
        XCTAssertEqual(result.entries[0].secondaryText, "00:00:59")
        XCTAssertNotNil(result.entries[0].accessoryText)
        XCTAssertTrue(result.entries[0].allowsStatusToggle)
        XCTAssertTrue(result.entries[0].isDone)
    }

    func testHistoryDataBuilderGroupsWeeksAcrossBoundaries() throws {
        let fileOne = try createHistoryFile(name: "2024-01-01.txt", contents: "00:01:00\n")
        let fileTwo = try createHistoryFile(name: "2024-01-08.txt", contents: "00:02:00\n")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let buckets = HistoryDataBuilder.groupedBuckets(
            for: [fileOne, fileTwo],
            mode: .week,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets[0].totalSeconds, 120)
        XCTAssertEqual(buckets[0].fileCount, 1)
        XCTAssertEqual(buckets[1].totalSeconds, 60)
        XCTAssertEqual(buckets[1].fileCount, 1)
    }

    func testHistoryDataBuilderGroupsMonthsAcrossBoundaries() throws {
        let fileOne = try createHistoryFile(name: "2024-01-31.txt", contents: "00:01:30\n")
        let fileTwo = try createHistoryFile(name: "2024-02-01.txt", contents: "00:02:30\n")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let buckets = HistoryDataBuilder.groupedBuckets(
            for: [fileOne, fileTwo],
            mode: .month,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets[0].totalSeconds, 150)
        XCTAssertEqual(buckets[1].totalSeconds, 90)
    }

    func testHistoryDataBuilderFormatsSummaryDurationAsHHMMSS() {
        XCTAssertEqual(HistoryDataBuilder.formatSummaryDuration(59), "00:00:59")
        XCTAssertEqual(HistoryDataBuilder.formatSummaryDuration(3661), "01:01:01")
    }

    func testHistoryViewModeSelectionCanBePersistedInUserDefaults() {
        let key = HistoryPage.viewModeStorageKey
        let defaults = UserDefaults.standard
        let originalValue = defaults.string(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(HistoryViewMode.month.rawValue, forKey: key)

        XCTAssertEqual(defaults.string(forKey: key), HistoryViewMode.month.rawValue)
        XCTAssertEqual(HistoryViewMode(rawValue: defaults.string(forKey: key) ?? ""), .month)
    }

    func testClockModelBuildsTodayFileURLInsideStorageDirectory() {
        let url = ClockModel.currentDayFileURL(storageURL: tempDirectory, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(url.deletingLastPathComponent(), tempDirectory)
        XCTAssertEqual(url.lastPathComponent, "1970-01-01.txt")

        let projectURL = ClockModel.currentDayFileURL(
            storageURL: tempDirectory,
            projectID: "project-123",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(projectURL.deletingLastPathComponent().lastPathComponent, "project-123")
        XCTAssertEqual(projectURL.lastPathComponent, "1970-01-01.txt")
    }

    func testClockModelUsesBuildSpecificStorageFolder() {
        XCTAssertEqual(ClockModel.storageFolderName(bundleIdentifier: "com.example.clocker.dev"), "Clocker-Dev")
        XCTAssertEqual(ClockModel.storageFolderName(bundleIdentifier: "com.example.clocker"), "Clocker")
    }

    func testProjectStorePersistsProjectsAndActiveSelection() {
        let store = ProjectStore(storageURL: tempDirectory)
        let projects = [
            ClockProject.defaultProject,
            ClockProject(id: "project-123", name: "Design")
        ]

        store.saveProjects(projects)
        store.saveActiveProjectID("project-123")

        XCTAssertEqual(store.loadProjects(), projects)
        XCTAssertEqual(store.loadActiveProjectID(projects: projects), "project-123")
    }

    func testClockModelCreatesAndSwitchesProjects() {
        let store = ProjectStore(storageURL: tempDirectory)
        let writer = TimeWriter(storageURL: tempDirectory)
        let model = ClockModel(projectStore: store, timeWriter: writer)

        XCTAssertEqual(model.activeProjectID, ClockProject.defaultID)
        XCTAssertEqual(model.activeProjectName, ClockProject.defaultProjectName)

        let created = model.createProject(named: "Ops")
        XCTAssertEqual(created?.name, "Ops")
        XCTAssertEqual(model.activeProjectName, "Ops")
        XCTAssertEqual(model.activeProjectID, created?.id)

        model.switchToProject(ClockProject.defaultID)
        XCTAssertEqual(model.activeProjectName, ClockProject.defaultProjectName)
        XCTAssertEqual(model.activeProjectID, ClockProject.defaultID)
    }

    func testAppUpdateServiceNormalizesGitHubReleaseTagsAndAssetNames() throws {
        let payload = """
        [
          {
            "tag_name": "v1.0.0",
            "prerelease": false,
            "assets": [
              {
                "name": "Clocker-v1.0.0.zip",
                "browser_download_url": "https://example.com/Clocker-v1.0.0.zip",
                "content_type": "application/zip"
              }
            ],
            "body": "Release notes",
            "name": "v1.0.0",
            "html_url": "https://example.com/releases/tag/v1.0.0"
          }
        ]
        """.data(using: .utf8)!

        let normalized = GitHubReleaseNormalizer.normalizeReleasePayload(payload)
        let json = try XCTUnwrap(String(data: normalized, encoding: .utf8))

        XCTAssertTrue(json.contains(#""tag_name":"1.0.0""#))
        XCTAssertTrue(json.contains(#""name":"Clocker-1.0.0.zip""#))
        XCTAssertFalse(json.contains(#""tag_name":"v1.0.0""#))
        XCTAssertFalse(json.contains(#""name":"Clocker-v1.0.0.zip""#))
    }

    func testAppUpdateServiceTreatsCancelledAsNoUpdate() {
        XCTAssertTrue(AppUpdateService.shouldTreatAsNoUpdate(AUError.cancelled))
        XCTAssertTrue(AppUpdateService.shouldTreatAsNoUpdate(AppUpdater.Error.noValidUpdate))
        XCTAssertFalse(AppUpdateService.shouldTreatAsNoUpdate(AppUpdater.Error.downloadFailed))
    }

    private func todayFileURL() -> URL {
        ClockModel.currentDayFileURL(storageURL: tempDirectory)
    }

    private func createHistoryFile(name: String, contents: String) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

}
