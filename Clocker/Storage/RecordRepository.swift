import Foundation

actor RecordRepository {
    private let localStore: DailyRecordStoreProtocol
    private let externalStore: DailyRecordStoreProtocol?

    init(localStore: DailyRecordStoreProtocol, externalStore: DailyRecordStoreProtocol?) {
        self.localStore = localStore
        self.externalStore = externalStore
    }

    func loadAll() async -> [DailyRecord] {
        var mergedByDate: [String: DailyRecord] = [:]

        if let localRecords = try? await localStore.loadAll() {
            for record in localRecords {
                mergedByDate[record.dateKey] = record
            }
        }

        if let externalStore, let externalRecords = try? await externalStore.loadAll() {
            for record in externalRecords {
                if let existing = mergedByDate[record.dateKey], existing.updatedAt > record.updatedAt {
                    continue
                }
                mergedByDate[record.dateKey] = record
            }
        }

        return mergedByDate.values.sorted { $0.dateKey > $1.dateKey }
    }

    func saveToLocal(_ record: DailyRecord) async {
        try? await localStore.save(record)
    }

    func saveToExternal(_ record: DailyRecord) async throws {
        guard let externalStore else { return }
        try await externalStore.save(record)
    }

    func mirrorLocalRecordsToExternal() async throws {
        guard let externalStore else { return }

        let localRecords = try await localStore.loadAll()
        let externalFiles = try await externalStore.existingFileNames()

        for record in localRecords {
            let fileName = "\(record.dateKey).json"
            if externalFiles.contains(fileName) {
                continue
            }
            try await externalStore.save(record)
        }
    }
}
