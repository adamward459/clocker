import XCTest
@testable import Clocker

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

    private func todayFileURL() -> URL {
        ClockModel.currentDayFileURL(storageURL: tempDirectory)
    }

}
