import Foundation
import SwiftData

/// Builds the SwiftData container used by the app and by tests.
enum PersistenceController {
    static let schema = Schema([PlayerProfile.self, RunRecord.self])

    /// Creates a container. Pass `inMemory: true` for tests and UI-test runs
    /// so nothing touches the player's real progress.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration("CraterHoardSlope", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
