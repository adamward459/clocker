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

        let fileURL = ClockService.currentDayFileURL(storageURL: tempDirectory, projectID: "project-123")
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

    func testClockServiceParsesRestoredTimeFromLastNonEmptyLine() {
        XCTAssertEqual(ClockService.parseElapsedSeconds(from: "00:01\n00:42\n"), 42)
        XCTAssertEqual(ClockService.parseElapsedSeconds(from: "\n 01:02:03 \n\n"), 3723)
        XCTAssertNil(ClockService.parseElapsedSeconds(from: ""))
        XCTAssertNil(ClockService.parseElapsedSeconds(from: "bad\nvalue"))
    }

    func testClockServiceFormatsElapsedTime() {
        XCTAssertEqual(ClockService.formatElapsed(59), "00:59")
        XCTAssertEqual(ClockService.formatElapsed(61), "01:01")
        XCTAssertEqual(ClockService.formatElapsed(3661), "1:01:01")
    }

    func testClockServiceParsesSessionDurationsAndTrailingSeparator() {
        let contents = """
        00:01
        00:02
        ---
        00:03
        00:04
        """

        XCTAssertEqual(ClockService.parseSessionDurations(from: contents), [2, 4])
        XCTAssertEqual(ClockService.parseElapsedSeconds(from: contents), 4)
        XCTAssertEqual(ClockService.parseElapsedSeconds(from: "00:01\n---\n"), 0)
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

    func testClockServiceCreatesAndSwitchesProjects() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let inboxProjectID = try XCTUnwrap(clockService.projects.first?.id)

        XCTAssertEqual(clockService.activeProjectID, inboxProjectID)
        XCTAssertEqual(clockService.activeProjectName, Project.defaultName)

        let created = try XCTUnwrap(clockService.createProject(named: "Ops"))
        XCTAssertEqual(created.name, "Ops")
        XCTAssertEqual(clockService.activeProjectName, "Ops")
        XCTAssertEqual(clockService.activeProjectID, created.id)

        _ = clockService.switchToProject(inboxProjectID)
        XCTAssertEqual(clockService.activeProjectName, Project.defaultName)
        XCTAssertEqual(clockService.activeProjectID, inboxProjectID)

        let persistedAppState = try XCTUnwrap(appStateService.loadAppState())
        XCTAssertEqual(persistedAppState.selectedProject?.id, clockService.activeProjectID)
        XCTAssertNotNil(projectSessionService.loadProjects().first(where: { $0.id == created.id }))
    }

    func testHistoryDataBuilderBuildsSessionEntriesInWeekMode() throws {
        let sessions = [
            makeHistorySession(
                dateKey: "2026-01-01",
                createdAt: Date(timeIntervalSince1970: 60),
                elapsedSeconds: 59,
                status: .done
            )
        ]

        let result = HistoryDataBuilder.makeResult(
            for: sessions,
            mode: .week
        )

        XCTAssertEqual(result.summaryText, "00:00:59")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].secondaryText, "2026-01-01")
        XCTAssertEqual(result.entries[0].trailingText, "00:00:59")
        XCTAssertEqual(result.entries[0].accessoryText, "Done")
        XCTAssertEqual(result.entries[0].children.count, 0)
    }

    func testHistoryDataBuilderBuildsSessionChildrenInWeekMode() throws {
        let sessions = [
            makeHistorySession(
                dateKey: "2026-01-02",
                createdAt: Date(timeIntervalSince1970: 120),
                elapsedSeconds: 2,
                status: .done
            ),
            makeHistorySession(
                dateKey: "2026-01-02",
                createdAt: Date(timeIntervalSince1970: 180),
                elapsedSeconds: 3,
                status: .done
            )
        ]

        let result = HistoryDataBuilder.makeResult(
            for: sessions,
            mode: .week
        )

        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.summaryText, "00:00:05")
        XCTAssertEqual(result.entries[0].trailingText, "00:00:03")
        XCTAssertEqual(result.entries[1].trailingText, "00:00:02")
    }

    func testHistoryDataBuilderGroupsWeeksAcrossBoundaries() throws {
        let fileOne = makeHistorySession(
            dateKey: "2024-01-01",
            createdAt: Date(timeIntervalSince1970: 60),
            elapsedSeconds: 60,
            status: .done
        )
        let fileTwo = makeHistorySession(
            dateKey: "2024-01-08",
            createdAt: Date(timeIntervalSince1970: 120),
            elapsedSeconds: 120,
            status: .done
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let buckets = HistoryDataBuilder.groupedBuckets(
            for: [fileOne, fileTwo],
            mode: .week,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets[0].totalSeconds, 120)
        XCTAssertEqual(buckets[0].sessionCount, 1)
        XCTAssertEqual(buckets[1].totalSeconds, 60)
        XCTAssertEqual(buckets[1].sessionCount, 1)
    }

    func testHistoryDataBuilderGroupsMonthsAcrossBoundaries() throws {
        let fileOne = makeHistorySession(
            dateKey: "2024-01-31",
            createdAt: Date(timeIntervalSince1970: 60),
            elapsedSeconds: 90,
            status: .done
        )
        let fileTwo = makeHistorySession(
            dateKey: "2024-02-01",
            createdAt: Date(timeIntervalSince1970: 120),
            elapsedSeconds: 150,
            status: .done
        )

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

    func testClockServiceBuildsTodayFileURLInsideStorageDirectory() {
        let url = ClockService.currentDayFileURL(storageURL: tempDirectory, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(url.deletingLastPathComponent(), tempDirectory)
        XCTAssertEqual(url.lastPathComponent, "1970-01-01.txt")

        let projectURL = ClockService.currentDayFileURL(
            storageURL: tempDirectory,
            projectID: "project-123",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(projectURL.deletingLastPathComponent().lastPathComponent, "project-123")
        XCTAssertEqual(projectURL.lastPathComponent, "1970-01-01.txt")
    }

    func testClockServiceUsesBuildSpecificStorageFolder() {
        XCTAssertEqual(ClockService.storageFolderName(bundleIdentifier: "com.example.clocker.dev"), "Clocker-Dev")
        XCTAssertEqual(ClockService.storageFolderName(bundleIdentifier: "com.example.clocker"), "Clocker")
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

    func testClockStateRestorerCreatesDefaultProjectWhenStoreIsEmpty() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()

        let result = clockService.restoreTodayRecordIfAvailable()

        XCTAssertEqual(result.projects.count, 1)
        XCTAssertEqual(result.selectedProject.name, Project.defaultName)
        XCTAssertNil(result.session)
        XCTAssertEqual(result.restoreState, .unavailable)
        XCTAssertEqual(clockService.projects.count, 1)
        XCTAssertEqual(clockService.activeProjectName, Project.defaultName)

        let persistedAppState = try XCTUnwrap(appStateService.loadAppState())
        XCTAssertEqual(persistedAppState.selectedProject?.id, result.selectedProject.id)
        XCTAssertNil(persistedAppState.currentSession)
        XCTAssertEqual(projectSessionService.loadProjects().count, 1)
    }

    func testClockStoreRestoresSelectedProjectAndLiveSessionWithoutAutoStarting() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Design"))
        let session = try XCTUnwrap(
            projectSessionService.createSession(
                for: project.id,
                dateKey: ClockService.todayString(),
                elapsedSeconds: 125,
                startedAt: .now.addingTimeInterval(-125),
                status: .running
            )
        )

        appStateService.setSelectedProject(project)
        appStateService.setCurrentSession(session)

        let result = clockService.restoreTodayRecordIfAvailable()

        XCTAssertEqual(result.selectedProject.id, project.id)
        XCTAssertEqual(result.session?.id, session.id)
        XCTAssertEqual(result.isRunning, false)
        XCTAssertEqual(result.displayTime, "02:05")
        XCTAssertEqual(result.restoreState, .restored)
        XCTAssertEqual(clockService.activeProjectID, project.id)
        XCTAssertEqual(clockService.displayTime, "02:05")
        XCTAssertFalse(clockService.isRunning)
        XCTAssertEqual(result.session?.status, .paused)

        let persistedAppState = try XCTUnwrap(appStateService.loadAppState())
        XCTAssertEqual(persistedAppState.selectedProject?.id, project.id)
        XCTAssertEqual(persistedAppState.currentSession?.id, session.id)
        XCTAssertEqual(persistedAppState.currentSession?.status, .paused)
    }

    func testClockStoreStartStopAndResetUpdateSwiftDataState() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Ops"))
        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        XCTAssertEqual(clockService.activeProjectID, project.id)
        XCTAssertFalse(clockService.isRunning)

        let startedSession = try XCTUnwrap(clockService.start())
        XCTAssertTrue(clockService.isRunning)
        XCTAssertEqual(startedSession.projectId, project.id)
        XCTAssertEqual(startedSession.status, .running)
        XCTAssertEqual(clockService.activeSession?.status, .running)

        let stoppedSession = try XCTUnwrap(clockService.stop())
        XCTAssertFalse(clockService.isRunning)
        XCTAssertEqual(stoppedSession.status, .done)
        XCTAssertEqual(stoppedSession.projectId, project.id)
        XCTAssertEqual(appStateService.loadAppState()?.currentSession?.id, stoppedSession.id)

        _ = clockService.reset()
        XCTAssertEqual(clockService.displayTime, "00:00")
        XCTAssertNil(appStateService.loadAppState()?.currentSession)
        XCTAssertEqual(projectSessionService.loadSessions(for: project.id).first(where: { $0.dateKey == ClockService.todayString() }), nil)
    }

    func testClockServiceStartResumesUndoneSessionInsteadOfCreatingANewOne() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Design"))
        let undoneSession = try XCTUnwrap(
            projectSessionService.createSession(
                for: project.id,
                dateKey: ClockService.todayString(),
                elapsedSeconds: 45,
                startedAt: nil,
                status: .undone
            )
        )

        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        let startedSession = try XCTUnwrap(clockService.start())

        XCTAssertEqual(startedSession.id, undoneSession.id)
        XCTAssertEqual(startedSession.status, .running)
        XCTAssertTrue(clockService.isRunning)
        XCTAssertEqual(projectSessionService.loadSessions(for: project.id).count, 1)
    }

    func testClockServiceStartNewSessionForcesANewSession() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Ops"))
        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        let firstSession = try XCTUnwrap(clockService.start())
        _ = clockService.stop()

        let newSession = try XCTUnwrap(clockService.startNewSession())

        XCTAssertNotEqual(newSession.id, firstSession.id)
        XCTAssertEqual(newSession.status, .running)
        XCTAssertEqual(projectSessionService.loadSessions(for: project.id).filter { $0.dateKey == ClockService.todayString() }.count, 2)
    }

    func testClockServiceMarksCurrentSessionDoneAndPausesClock() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Design"))
        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        let startedSession = try XCTUnwrap(clockService.start())
        clockService.updateHistorySessionsStatus([startedSession], to: .done)

        let currentSession = try XCTUnwrap(clockService.activeSession)
        XCTAssertEqual(currentSession.id, startedSession.id)
        XCTAssertEqual(currentSession.status, .done)
        XCTAssertEqual(clockService.displayTime, ClockService.formatElapsed(startedSession.elapsedSeconds))
        XCTAssertFalse(clockService.isRunning)
        XCTAssertEqual(appStateService.loadAppState()?.currentSession?.id, currentSession.id)
        XCTAssertEqual(projectSessionService.loadSessions(for: project.id).filter { $0.dateKey == ClockService.todayString() }.count, 1)
        XCTAssertEqual(startedSession.status, .done)
    }

    func testClockServiceMarksCurrentSessionUndoneAndPausesClock() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Ops"))
        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        let startedSession = try XCTUnwrap(clockService.start())
        clockService.updateHistorySessionsStatus([startedSession], to: .undone)

        let currentSession = try XCTUnwrap(clockService.activeSession)
        XCTAssertEqual(currentSession.id, startedSession.id)
        XCTAssertEqual(currentSession.status, .undone)
        XCTAssertEqual(clockService.displayTime, ClockService.formatElapsed(startedSession.elapsedSeconds))
        XCTAssertFalse(clockService.isRunning)
        XCTAssertEqual(appStateService.loadAppState()?.currentSession?.id, currentSession.id)
        XCTAssertEqual(projectSessionService.loadSessions(for: project.id).filter { $0.dateKey == ClockService.todayString() }.count, 1)
        XCTAssertEqual(startedSession.status, .undone)
    }

    func testClockServiceDeletesActiveSessionAndClearsState() throws {
        let (clockService, appStateService, projectSessionService, _) = try makeClockStore()
        let project = try XCTUnwrap(projectSessionService.createProject(named: "Ops"))
        appStateService.setSelectedProject(project)
        _ = clockService.switchToProject(project.id)

        let startedSession = try XCTUnwrap(clockService.start())
        clockService.deleteSession(startedSession.id)

        XCTAssertNil(clockService.activeSession)
        XCTAssertFalse(clockService.isRunning)
        XCTAssertEqual(clockService.displayTime, "00:00")
        XCTAssertTrue(projectSessionService.loadSessions(for: project.id).isEmpty)
        XCTAssertNil(appStateService.loadAppState()?.currentSession)
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
        ClockService.currentDayFileURL(storageURL: tempDirectory)
    }

    private func makeProjectStore(legacyStorageURL: URL, modelStoreURL: URL? = nil) throws -> ProjectStore {
        let container = try makeModelContainer(storeURL: modelStoreURL)
        return ProjectStore(legacyStorageURL: legacyStorageURL, modelContainer: container)
    }

    private func makeClockStore() throws -> (
        clockService: ClockService,
        appStateService: AppStateService,
        projectSessionService: ProjectSessionService,
        modelContainer: ModelContainer
    ) {
        let modelContainer = try makeClockServiceContainer()
        let projectSessionService = ProjectSessionService(modelContainer: modelContainer)
        let appStateService = AppStateService(modelContainer: modelContainer)
        let clockService = ClockService(
            projectSessionService: projectSessionService,
            appStateService: appStateService
        )
        return (clockService, appStateService, projectSessionService, modelContainer)
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

    private func makeClockServiceContainer() throws -> ModelContainer {
        let schema = Schema([Project.self, Session.self, AppState.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeHistorySession(
        dateKey: String,
        createdAt: Date,
        elapsedSeconds: Int,
        status: Session.Status
    ) -> Session {
        Session(
            projectId: UUID(),
            dateKey: dateKey,
            elapsedSeconds: elapsedSeconds,
            startedAt: status == .running ? createdAt.addingTimeInterval(-Double(elapsedSeconds)) : nil,
            status: status,
            createdAt: createdAt
        )
    }

}
