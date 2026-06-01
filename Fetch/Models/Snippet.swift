import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var code: String
    var language: String
    var expiresAt: Date?
    var note: String?

    init(
        id: UUID = UUID(),
        title: String,
        code: String,
        language: String = "bash",
        expiresAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.code = code
        self.language = language
        self.expiresAt = expiresAt
        self.note = note
    }
}
