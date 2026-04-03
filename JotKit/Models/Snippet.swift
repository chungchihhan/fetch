import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var code: String
    var language: String

    init(id: UUID = UUID(), title: String, code: String, language: String = "bash") {
        self.id = id
        self.title = title
        self.code = code
        self.language = language
    }
}
