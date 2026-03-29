import AppKit
import Combine
import Foundation

@MainActor
final class ClockStore: ObservableObject {
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isRunning = false
    @Published private(set) var activeDateKey: String
    @Published private(set) var history: [DailyRecord] = []
    @Published private(set) var syncState: SyncState = .localOnly
    @Published private(set) var selectedFolderURL: URL?

    let calendar: Calendar

    private let now: () -> Date
    private let localCacheStore: LocalCacheStore
    private let bookmarkStore: ExternalFolderBookmarkStore
    private let externalWriteInterval: TimeInterval
    private var repository: RecordRepository

    private var timer: Timer?
    private var lastTickAt: Date?
    private var lastExternalWriteAt: Date?
    private var cancellables = Set<AnyCancellable>()

    init(
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        localCacheStore: LocalCacheStore = LocalCacheStore(),
        bookmarkStore: ExternalFolderBookmarkStore = ExternalFolderBookmarkStore(),
        repository: RecordRepository? = nil,
        cloudWriteInterval: TimeInterval = 8
    ) {
        let resolvedFolderURL = bookmarkStore.loadURL()
        let resolvedRepository = repository ?? ClockStore.makeRepository(externalURL: resolvedFolderURL)

        self.calendar = calendar
        self.now = now
        self.localCacheStore = localCacheStore
        self.bookmarkStore = bookmarkStore
        self.externalWriteInterval = cloudWriteInterval
        self.selectedFolderURL = resolvedFolderURL
        self.repository = resolvedRepository

        let initialNow = now()
        self.activeDateKey = DateKey.string(from: initialNow, calendar: calendar)
        self.syncState = resolvedFolderURL == nil ? .localOnly : .folderSelected

        restoreState(for: initialNow)
        observeLifecycle()

        Task {
            await refreshHistory()
            await syncExternalMirrorIfNeeded()
        }
    }

    var formattedElapsed: String {
        DurationFormatter.string(from: elapsedSeconds)
    }

    var todayRecord: DailyRecord {
        DailyRecord(dateKey: activeDateKey, elapsedSeconds: elapsedSeconds, updatedAt: now())
    }

    var pastRecords: [DailyRecord] {
        history.filter { $0.dateKey != activeDateKey }
    }

    func start() {
        reconcileCurrentDay()
        guard !isRunning else { return }

        isRunning = true
        lastTickAt = now()
        persistLocalCache()
        startTimerIfNeeded()
    }

    func stop() {
        guard isRunning else { return }

        advanceClock(to: now(), forceExternalWrite: true)
        isRunning = false
        lastTickAt = nil
        invalidateTimerIfNeeded()
        persistLocalCache()
        Task {
            await flushCurrentDayToExternal()
        }
    }

    func resetToday() {
        reconcileCurrentDay()
        elapsedSeconds = 0
        lastTickAt = isRunning ? now() : nil
        persistLocalCache()
        Task {
            await persistCurrentDay(forceExternalWrite: true)
        }
    }

    func reconcileCurrentDay() {
        advanceClock(to: now(), forceExternalWrite: false)
    }

    func refreshHistory() async {
        let records = await repository.loadAll()
        await MainActor.run {
            self.history = records
        }
    }

    func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Clocker will import existing day files from this folder and keep saving future records there."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try bookmarkStore.save(url: url)
            selectedFolderURL = url
            repository = Self.makeRepository(externalURL: url)
            syncState = .folderSelected
            Task {
                await syncExternalMirrorIfNeeded()
                await refreshHistory()
                await persistCurrentDay(forceExternalWrite: true)
            }
        } catch {
            syncState = .localOnly
        }
    }

    func clearSaveFolder() {
        bookmarkStore.clear()
        selectedFolderURL = nil
        repository = Self.makeRepository(externalURL: nil)
        syncState = .localOnly

        Task {
            await refreshHistory()
        }
    }

    func flushCurrentDayToExternal() async {
        await persistCurrentDay(forceExternalWrite: true)
    }

    private func observeLifecycle() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reconcileCurrentDay()
                Task { await self.refreshHistory() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reconcileCurrentDay()
                Task { await self.flushCurrentDayToExternal() }
            }
            .store(in: &cancellables)
    }

    private func restoreState(for launchDate: Date) {
        activeDateKey = DateKey.string(from: launchDate, calendar: calendar)

        guard let cache = try? localCacheStore.load() else {
            persistLocalCache()
            return
        }

        if cache.dateKey == activeDateKey {
            elapsedSeconds = cache.elapsedSeconds
            isRunning = cache.isRunning
            lastTickAt = isRunning ? launchDate : nil
        } else {
            if cache.elapsedSeconds > 0 {
                let archived = DailyRecord(
                    dateKey: cache.dateKey,
                    elapsedSeconds: cache.elapsedSeconds,
                    updatedAt: cache.updatedAt
                )
                Task {
                    await repository.saveToLocal(archived)
                    await refreshHistory()
                }
            }
            elapsedSeconds = 0
            isRunning = false
            lastTickAt = nil
            persistLocalCache()
        }

        if isRunning {
            startTimerIfNeeded()
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerTick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func invalidateTimerIfNeeded() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimerTick() {
        advanceClock(to: now(), forceExternalWrite: false)
    }

    private func advanceClock(to date: Date, forceExternalWrite: Bool) {
        let incomingDateKey = DateKey.string(from: date, calendar: calendar)

        if incomingDateKey != activeDateKey {
            if isRunning, let lastTickAt {
                let previousDayEnd = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: lastTickAt)
                ) ?? date
                let previousDayDelta = max(0, Int(previousDayEnd.timeIntervalSince(lastTickAt)))
                elapsedSeconds += previousDayDelta
            }

            rollover(to: date, newDateKey: incomingDateKey)

            if isRunning {
                let startOfIncomingDay = calendar.startOfDay(for: date)
                elapsedSeconds = max(0, Int(date.timeIntervalSince(startOfIncomingDay)))
                lastTickAt = date
            }
        }

        guard isRunning else {
            persistLocalCache()
            return
        }

        if let lastTickAt {
            let delta = max(0, Int(date.timeIntervalSince(lastTickAt)))
            if delta > 0 {
                elapsedSeconds += delta
                self.lastTickAt = date
            }
        } else {
            lastTickAt = date
        }

        persistLocalCache()

        Task {
            await persistCurrentDay(forceExternalWrite: forceExternalWrite)
        }
    }

    private func rollover(to date: Date, newDateKey: String) {
        let previousRecord = DailyRecord(
            dateKey: activeDateKey,
            elapsedSeconds: elapsedSeconds,
            updatedAt: date
        )

        Task {
            await repository.saveToLocal(previousRecord)
            if selectedFolderURL != nil {
                do {
                    await MainActor.run { self.syncState = .savingToFolder }
                    try await repository.saveToExternal(previousRecord)
                    await MainActor.run { self.syncState = .folderSelected }
                } catch {
                    await MainActor.run { self.syncState = .localOnly }
                }
            }
            await refreshHistory()
        }

        activeDateKey = newDateKey
        elapsedSeconds = 0
        lastTickAt = isRunning ? date : nil
        lastExternalWriteAt = nil
        persistLocalCache()
    }

    private func persistLocalCache() {
        let cache = RuntimeCache(
            dateKey: activeDateKey,
            elapsedSeconds: elapsedSeconds,
            isRunning: isRunning,
            updatedAt: now()
        )
        try? localCacheStore.save(cache)
    }

    private func persistCurrentDay(forceExternalWrite: Bool) async {
        let record = DailyRecord(dateKey: activeDateKey, elapsedSeconds: elapsedSeconds, updatedAt: now())
        await repository.saveToLocal(record)
        await refreshHistory()

        guard selectedFolderURL != nil else {
            await MainActor.run {
                self.syncState = .localOnly
            }
            return
        }

        let currentNow = now()
        let shouldWriteExternally: Bool
        if forceExternalWrite {
            shouldWriteExternally = true
        } else if let lastExternalWriteAt {
            shouldWriteExternally = currentNow.timeIntervalSince(lastExternalWriteAt) >= externalWriteInterval
        } else {
            shouldWriteExternally = true
        }

        guard shouldWriteExternally else { return }

        do {
            await MainActor.run {
                self.syncState = .savingToFolder
            }
            try await repository.saveToExternal(record)
            lastExternalWriteAt = currentNow
            await MainActor.run {
                self.syncState = .folderSelected
            }
        } catch {
            await MainActor.run {
                self.syncState = .localOnly
            }
        }
    }

    private func syncExternalMirrorIfNeeded() async {
        guard selectedFolderURL != nil else { return }

        do {
            await MainActor.run {
                self.syncState = .savingToFolder
            }
            try await repository.mirrorLocalRecordsToExternal()
            await MainActor.run {
                self.syncState = .folderSelected
            }
        } catch {
            await MainActor.run {
                self.syncState = .localOnly
            }
        }
    }

    private static func makeRepository(externalURL: URL?) -> RecordRepository {
        let fileManager = FileManager.default
        let supportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let localHistoryURL = supportURL
            .appendingPathComponent("Clocker", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)

        return RecordRepository(
            localStore: DailyRecordStore(baseURL: localHistoryURL),
            externalStore: externalURL.map { DailyRecordStore(baseURL: $0, requiresSecurityScopedAccess: true) }
        )
    }
}
