import XCTest
@testable import Clocker

@MainActor
final class ClockStoreTests: XCTestCase {
    func testMidnightRolloverCreatesPastRecordAndKeepsRunning() async {
        let localStore = InMemoryDailyRecordStore()
        let cloudStore = InMemoryDailyRecordStore()
        let repository = RecordRepository(localStore: localStore, externalStore: cloudStore)
        let cacheStore = TestLocalCacheStore()

        let clock = TestClock(date: makeDate("2024-03-10T23:59:59Z"))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let store = ClockStore(
            calendar: calendar,
            now: { clock.date },
            localCacheStore: cacheStore.asLocalCacheStore(),
            repository: repository,
            cloudWriteInterval: 8
        )

        store.start()
        clock.date = makeDate("2024-03-11T00:00:00Z")
        store.reconcileCurrentDay()
        clock.date = makeDate("2024-03-11T00:00:01Z")
        store.reconcileCurrentDay()
        await Task.yield()
        await Task.yield()
        await store.refreshHistory()

        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.formattedElapsed, "00:00:01")
        XCTAssertEqual(store.pastRecords.count, 1)
        XCTAssertEqual(store.pastRecords.first?.elapsedSeconds, 1)
    }

    func testResetClearsToday() async {
        let repository = RecordRepository(
            localStore: InMemoryDailyRecordStore(),
            externalStore: InMemoryDailyRecordStore()
        )
        let cacheStore = TestLocalCacheStore()

        let fixedDate = Date(timeIntervalSince1970: 1_710_748_800)
        let store = ClockStore(
            calendar: Calendar(identifier: .gregorian),
            now: { fixedDate },
            localCacheStore: cacheStore.asLocalCacheStore(),
            repository: repository
        )

        store.start()
        store.resetToday()

        XCTAssertEqual(store.elapsedSeconds, 0)
        XCTAssertTrue(store.isRunning)
    }
}

private func makeDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: value)!
}

private final class TestClock {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}

private actor InMemoryDailyRecordStore: DailyRecordStoreProtocol {
    private var records: [String: DailyRecord] = [:]

    func loadAll() async throws -> [DailyRecord] {
        records.values.sorted { $0.dateKey > $1.dateKey }
    }

    func save(_ record: DailyRecord) async throws {
        records[record.dateKey] = record
    }

    func existingFileNames() async throws -> Set<String> {
        Set(records.keys.map { "\($0).json" })
    }
}

private final class TestLocalCacheStore {
    var cache: RuntimeCache?

    func asLocalCacheStore() -> LocalCacheStore {
        LocalCacheStore(adapter: self)
    }
}

private extension LocalCacheStore {
    init(adapter: TestLocalCacheStore) {
        self.init(loader: { adapter.cache }, saver: { adapter.cache = $0 })
    }
}
