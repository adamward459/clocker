import XCTest
@testable import Clocker
import AppUpdater
import SwiftData

@MainActor
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

    func testClockModelParsesSessionDurationsAndTrailingSeparator() {
        let contents = """
        00:01
        00:02
        ---
        00:03
        00:04
        """

        XCTAssertEqual(ClockModel.parseSessionDurations(from: contents), [2, 4])
        XCTAssertEqual(ClockModel.parseElapsedSeconds(from: contents), 4)
        XCTAssertEqual(ClockModel.parseElapsedSeconds(from: "00:01\n---\n"), 0)
    }

    func testTimeWriterBeginsNewSessionWithSeparator() throws {
        let writer = TimeWriter(storageURL: tempDirectory)
        writer.persist("00:01")
        writer.waitUntilIdle()

        writer.beginNewSession(projectID: ClockProject.defaultID)
        writer.persist("00:02")
        writer.waitUntilIdle()

        let fileURL = todayFileURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "00:01\n---\n00:02\n")
    }

    func testClockModelStartNewSessionAppendsSeparatorAndResetsDisplay() throws {
        let writer = TimeWriter(storageURL: tempDirectory)
        writer.persist("00:05")
        writer.waitUntilIdle()

        let store = try makeProjectStore(legacyStorageURL: tempDirectory)
        let model = ClockModel(projectRepository: store, timeWriter: writer)

        model.startNewSession()
        model.stop()
        writer.waitUntilIdle()

        let fileURL = todayFileURL()
        XCTAssertEqual(model.displayTime, "00:00")
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "00:05\n---\n")
    }

    func testClockModelRestoresLiveSessionStateFromSwiftData() throws {
        let storeURL = tempDirectory.appendingPathComponent("SwiftData.store")
        let store = try makeProjectStore(
            legacyStorageURL: tempDirectory,
            modelStoreURL: storeURL
        )
        let projects = [
            ClockProject.defaultProject,
            ClockProject(id: "project-123", name: "Design")
        ]
        store.saveProjects(projects)
        store.saveActiveProjectID("project-123")
        store.saveLiveSessionState(
            ClockSessionState(
                activeProjectID: "project-123",
                elapsedSeconds: 125,
                trackingDate: ClockModel.todayString(),
                isRunning: true
            )
        )

        let model = ClockModel(
            projectRepository: store,
            timeWriter: TimeWriter(storageURL: tempDirectory)
        )

        XCTAssertEqual(model.activeProjectID, "project-123")
        XCTAssertEqual(model.displayTime, "02:05")
        XCTAssertTrue(model.isRunning)
        XCTAssertEqual(model.restoreState, .restored)

        model.stop()
        XCTAssertFalse(model.isRunning)

        let persistedSession = try XCTUnwrap(store.loadLiveSessionState())
        XCTAssertEqual(persistedSession.activeProjectID, "project-123")
        XCTAssertEqual(persistedSession.elapsedSeconds, 125)
        XCTAssertEqual(persistedSession.trackingDate, ClockModel.todayString())
        XCTAssertFalse(persistedSession.isRunning)

        model.reset()
        let resetSession = try XCTUnwrap(store.loadLiveSessionState())
        XCTAssertEqual(resetSession.elapsedSeconds, 0)
        XCTAssertFalse(resetSession.isRunning)
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
        XCTAssertEqual(result.entries[0].secondaryText, "1 session")
        XCTAssertEqual(result.entries[0].trailingText, "00:00:59")
        XCTAssertNotNil(result.entries[0].accessoryText)
        XCTAssertTrue(result.entries[0].allowsStatusToggle)
        XCTAssertTrue(result.entries[0].isDone)
        XCTAssertEqual(result.entries[0].children.count, 1)
        XCTAssertEqual(result.entries[0].children[0].title, "Session 1")
        XCTAssertEqual(result.entries[0].children[0].trailingText, "00:00:59")
    }

    func testHistoryDataBuilderBuildsSessionChildrenInFilesMode() throws {
        let fileURL = try createHistoryFile(
            name: "2026-01-02.txt",
            contents: "00:01\n00:02\n---\n00:01\n00:02\n00:03\n"
        )

        let result = HistoryDataBuilder.makeResult(
            for: [fileURL],
            mode: .files,
            isDone: { _ in false }
        )

        XCTAssertEqual(result.entries.count, 1)
        let day = result.entries[0]
        XCTAssertEqual(day.secondaryText, "2 sessions")
        XCTAssertEqual(day.trailingText, "00:00:05")
        XCTAssertEqual(day.children.count, 2)
        XCTAssertEqual(day.children[0].title, "Session 2")
        XCTAssertEqual(day.children[0].trailingText, "00:00:03")
        XCTAssertEqual(day.children[1].title, "Session 1")
        XCTAssertEqual(day.children[1].trailingText, "00:00:02")
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
        let store = try! makeProjectStore(legacyStorageURL: tempDirectory)
        let projects = [
            ClockProject.defaultProject,
            ClockProject(id: "project-123", name: "Design")
        ]

        store.saveProjects(projects)
        store.saveActiveProjectID("project-123")

        XCTAssertEqual(store.loadProjects(), projects)
        XCTAssertEqual(store.loadActiveProjectID(projects: projects), "project-123")
    }

    func testProjectStoreImportsLegacyJSONOnce() throws {
        let legacyProjects = [
            ClockProject(id: "project-123", name: "Design", lastUsedAt: Date(timeIntervalSince1970: 10)),
            ClockProject(id: "project-456", name: "Ops", lastUsedAt: Date(timeIntervalSince1970: 20))
        ]
        let projectsData = try JSONEncoder().encode(legacyProjects)
        try projectsData.write(to: tempDirectory.appendingPathComponent("projects.json"))

        let stateData = Data(#"{"activeProjectID":"project-456"}"#.utf8)
        try stateData.write(to: tempDirectory.appendingPathComponent("state.json"))

        let storeURL = tempDirectory.appendingPathComponent("SwiftData.store")
        let store = try makeProjectStore(
            legacyStorageURL: tempDirectory,
            modelStoreURL: storeURL
        )

        XCTAssertEqual(
            store.loadProjects(),
            [ClockProject.defaultProject] + legacyProjects
        )
        XCTAssertEqual(
            store.loadActiveProjectID(projects: store.loadProjects()),
            "project-456"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("projects.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("state.json").path))

        let reloadedStore = try makeProjectStore(
            legacyStorageURL: tempDirectory,
            modelStoreURL: storeURL
        )
        XCTAssertEqual(
            reloadedStore.loadProjects(),
            [ClockProject.defaultProject] + legacyProjects
        )
        XCTAssertEqual(
            reloadedStore.loadActiveProjectID(projects: reloadedStore.loadProjects()),
            "project-456"
        )
    }

    func testClockModelCreatesAndSwitchesProjects() {
        let store = try! makeProjectStore(legacyStorageURL: tempDirectory)
        let writer = TimeWriter(storageURL: tempDirectory)
        let model = ClockModel(projectRepository: store, timeWriter: writer)

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

    private func makeProjectStore(legacyStorageURL: URL, modelStoreURL: URL? = nil) throws -> ProjectStore {
        let container = try makeModelContainer(storeURL: modelStoreURL)
        return ProjectStore(legacyStorageURL: legacyStorageURL, modelContainer: container)
    }

    private func makeModelContainer(storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema([StoredProject.self, StoredAppState.self, StoredLiveSession.self])
        if let storeURL {
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func createHistoryFile(name: String, contents: String) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

}
